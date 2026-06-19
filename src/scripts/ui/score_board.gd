extends Node2D

var teams_data_path: String
const SCORE_BAR_SCENE = preload("res://scene/prefabs/score_bar.tscn")

# 在编辑器中将你的 TeamEditor 节点拖放到这里
@export var team_editor_node: Node

# 存储当前显示的score_bar实例
var score_bar_instances: Array = []

# score_bar的起始位置和间距
@export var start_y_position: float = 100.0
@export var bar_spacing: float = 85.0

# 动画相关变量
var animation_queue: Array = []
var is_animating: bool = false
const ANIMATION_DURATION: float = 0.4
const MOVE_DISTANCE: float = 100.0

func _ready() -> void:
    # 初始化路径变量
    teams_data_path = AppData.get_exe_dir() + "/userdata/teams/teams.json"
    
    # 游戏开始时，立即更新一次排名并显示排行榜
    update_ranks_and_display()
    
    # 连接到 TeamEditor 的信号，以便在数据保存时自动更新排名
    if team_editor_node and team_editor_node.has_signal("teams_data_saved"):
        team_editor_node.teams_data_saved.connect(update_ranks_and_display)
        print("ScoreBoard: Successfully connected to teams_data_saved signal.")
    else:
        print("ScoreBoard Warning: TeamEditor node not assigned in the inspector, or it lacks the 'teams_data_saved' signal.")
    
    # 也可以连接到now_player的team_data_changed信号
    _connect_to_team_data_signals()

func _connect_to_team_data_signals():
    """连接到可能改变队伍数据的信号"""
    # 延迟连接，确保所有节点都已准备好
    call_deferred("_delayed_connect_to_team_signals")

func _delayed_connect_to_team_signals():
    """延迟连接到队伍数据变更信号"""
    var connected_count = 0
    
    # 查找 now_player 节点并连接其 team_data_changed 信号
    var now_player_nodes = _find_nodes_with_script("now_player.gd")
    for node in now_player_nodes:
        if node.has_signal("team_data_changed"):
            if not node.team_data_changed.is_connected(update_ranks_and_display):
                node.team_data_changed.connect(update_ranks_and_display)
                print("ScoreBoard: Connected to team_data_changed signal from: " + node.name)
                connected_count += 1
    
    if connected_count > 0:
        print("ScoreBoard: Successfully connected to " + str(connected_count) + " team data signal(s)")

func _find_nodes_with_script(script_name: String) -> Array:
    """查找具有指定脚本的节点"""
    var result = []
    _search_nodes_recursive(get_tree().root, script_name, result)
    return result

func _search_nodes_recursive(node: Node, script_name: String, result: Array) -> void:
    """递归搜索节点"""
    if node.get_script():
        var script_path = node.get_script().resource_path
        if script_path.ends_with(script_name):
            result.append(node)
    
    for child in node.get_children():
        _search_nodes_recursive(child, script_name, result)

func update_ranks_and_display() -> void:
    """更新排名并重新显示排行榜"""
    print("ScoreBoard: Updating ranks and display...")
    
    # 首先更新排名数据
    update_ranks()
    
    # 然后重新显示排行榜
    display_scoreboard()

func display_scoreboard() -> void:
    """读取排序后的队伍数据并显示排行榜"""
    print("ScoreBoard: Displaying scoreboard...")
    
    # 清除现有的score_bar实例和动画队列
    clear_score_bars()
    animation_queue.clear()
    is_animating = false
    
    # 读取teams.json文件
    if not FileAccess.file_exists(teams_data_path):
        print("ScoreBoard: teams.json not found. Nothing to display.")
        return
    
    var file = FileAccess.open(teams_data_path, FileAccess.READ)
    if not file:
        print("ScoreBoard Error: Could not open teams.json for reading.")
        return
    
    var content = file.get_as_text()
    file.close()

    var teams_list = JSON.parse_string(content)
    if teams_list == null:
        print("ScoreBoard Error: Failed to parse teams.json. Invalid JSON format.")
        print("JSON content that failed to parse (first 500 chars):")
        print(content.substr(0, 500) + "..." if content.length() > 500 else content)
        return
    
    if not teams_list is Array:
        print("ScoreBoard Error: teams.json content is not a valid JSON array.")
        print("Parsed content type: " + str(typeof(teams_list)))
        return
    
    if teams_list.is_empty():
        print("ScoreBoard: No teams to display.")
        return
    
    # 确保队伍按排名排序（以防万一）
    teams_list.sort_custom(func(a, b): return a.get("rank", 999) < b.get("rank", 999))
    
    # 为每个队伍创建score_bar（但不立即显示）
    for i in range(teams_list.size()):
        var team_data = teams_list[i]
        create_score_bar(team_data, i)
    
    # 开始播放动画序列
    start_animation_sequence()

func create_score_bar(team_data: Dictionary, index: int) -> void:
    """为指定队伍创建并配置score_bar"""
    if not SCORE_BAR_SCENE:
        print("ScoreBoard Error: score_bar scene not loaded.")
        return
    
    # 实例化score_bar
    var score_bar_instance = SCORE_BAR_SCENE.instantiate()
    if not score_bar_instance:
        print("ScoreBoard Error: Failed to instantiate score_bar.")
        return
    
    # 设置最终位置
    var final_y = start_y_position + (index * bar_spacing)
    var start_y = final_y + MOVE_DISTANCE  # 起始位置向下偏移
    
    score_bar_instance.position.y = start_y
    score_bar_instance.modulate.a = 0.0  # 初始透明度为0
    
    # 添加到场景树
    add_child(score_bar_instance)
    score_bar_instances.append(score_bar_instance)
    
    # 配置score_bar显示的数据
    configure_score_bar(score_bar_instance, team_data)
    
    # 添加到动画队列
    animation_queue.append({
        "score_bar": score_bar_instance,
        "start_y": start_y,
        "final_y": final_y
    })

func start_animation_sequence() -> void:
    """开始播放动画序列，所有动画以0.25秒间隔依次开始"""
    if animation_queue.is_empty():
        return
    
    is_animating = true
    
    # 依次启动每个动画，间隔0.1秒
    for i in range(animation_queue.size()):
        # 延迟 i * 0.25 秒后开始该动画
        get_tree().create_timer(i * 0.25).timeout.connect(func(): animate_score_bar_at_index(i))
    
    # 计算总动画时间并设置完成回调
    var total_time = (animation_queue.size() - 1) * 0.25 + ANIMATION_DURATION
    get_tree().create_timer(total_time).timeout.connect(_on_all_animations_finished)

func animate_score_bar_at_index(index: int) -> void:
    """播放指定索引的score_bar动画"""
    if index >= animation_queue.size():
        return
    
    var anim_data = animation_queue[index]
    var score_bar = anim_data["score_bar"]
    var start_y = anim_data["start_y"]
    var final_y = anim_data["final_y"]
    
    if not is_instance_valid(score_bar):
        return
    
    # 创建Tween动画
    var tween = create_tween()
    tween.set_parallel(true)  # 允许并行动画
    
    # 透明度动画（对数函数：快速开始，然后变慢）
    tween.tween_method(
        func(alpha): score_bar.modulate.a = alpha,
        0.0,
        1.0,
        ANIMATION_DURATION
    ).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    
    # 位置动画（对数函数：快速开始，然后变慢）
    tween.tween_method(
        func(y): score_bar.position.y = y,
        start_y,
        final_y,
        ANIMATION_DURATION
    ).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _on_all_animations_finished() -> void:
    """所有动画完成后的回调"""
    is_animating = false
    print("ScoreBoard: All animations completed.")

func configure_score_bar(score_bar: Node, team_data: Dictionary) -> void:
    """配置score_bar显示的队伍数据"""
    # 如果score_bar有setup_team_data方法，使用它
    if score_bar.has_method("setup_team_data"):
        score_bar.setup_team_data(team_data)
    else:
        # 备用方案：直接设置UI元素
        var order_label = score_bar.get_node_or_null("Order")
        var team_name_label = score_bar.get_node_or_null("TeamName")
        var balance_label = score_bar.get_node_or_null("Balance")
        var score_label = score_bar.get_node_or_null("Score")
        var team_icon = score_bar.get_node_or_null("TeamIcon")
        
        if order_label:
            order_label.text = str(team_data.get("rank", "?"))
        if team_name_label:
            team_name_label.text = str(team_data.get("name", "Unknown"))
        if balance_label:
            balance_label.text = str(team_data.get("balance", 0))
        if score_label:
            score_label.text = str(team_data.get("score", 0))
        if team_icon:
            var icon_path = team_data.get("icon_path", "")
            if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
                var texture = _load_texture_from_path(icon_path)
                if texture:
                    team_icon.texture = texture

func _load_texture_from_path(path: String) -> Texture2D:
    """从路径加载纹理"""
    if path.is_empty():
        return null
    
    if not FileAccess.file_exists(path):
        return null
    
    if path.begins_with("res://"):
        return load(path)
    else:
        var image = Image.new()
        var error = image.load(path)
        if error == OK:
            return ImageTexture.create_from_image(image)
    
    return null

func clear_score_bars() -> void:
    """清除所有现有的score_bar实例"""
    for score_bar in score_bar_instances:
        if is_instance_valid(score_bar):
            score_bar.queue_free()
    score_bar_instances.clear()

func update_ranks() -> void:
    """
    读取 teams.json，根据分数计算排名，然后将更新后的数据写回文件。
    """
    print("ScoreBoard: Updating team ranks...")

    # 1. 读取 teams.json 文件
    if not FileAccess.file_exists(teams_data_path):
        print("ScoreBoard: teams.json not found. Nothing to rank.")
        return

    var file = FileAccess.open(teams_data_path, FileAccess.READ)
    if not file:
        print("ScoreBoard Error: Could not open teams.json for reading.")
        return

    var content = file.get_as_text()
    file.close()

    var teams_list = JSON.parse_string(content)
    if teams_list == null:
        print("ScoreBoard Error: Failed to parse teams.json. Invalid JSON format.")
        print("JSON content that failed to parse (first 500 chars):")
        print(content.substr(0, 500) + "..." if content.length() > 500 else content)
        return
    
    if not teams_list is Array:
        print("ScoreBoard Error: teams.json content is not a valid JSON array.")
        print("Parsed content type: " + str(typeof(teams_list)))
        return

    if teams_list.is_empty():
        print("ScoreBoard: No teams to rank.")
        return

    # 2. 按分数（score）降序排序
    teams_list.sort_custom(func(a, b): 
        var score_a = a.get("score", 0)
        var score_b = b.get("score", 0)
        return score_a > score_b
    )

    # 3. 计算并分配排名
    var current_rank = 1
    for i in range(teams_list.size()):
        # 对于第一名（索引为0）或分数低于前一名的情况
        if i > 0 and teams_list[i].get("score", 0) < teams_list[i-1].get("score", 0):
            # 排名等于其在列表中的位置（索引+1）
            current_rank = i + 1
        
        teams_list[i]["rank"] = current_rank

    # 4. 将更新后的列表写回 teams.json 文件
    var json_string = JSON.stringify(teams_list, "\t")
    var write_file = FileAccess.open(teams_data_path, FileAccess.WRITE)
    if write_file:
        write_file.store_string(json_string)
        write_file.close()
        print("ScoreBoard: Ranks updated and saved to teams.json.")
    else:
        print("ScoreBoard Error: Could not open teams.json for writing. Error code: " + str(FileAccess.get_open_error()))
