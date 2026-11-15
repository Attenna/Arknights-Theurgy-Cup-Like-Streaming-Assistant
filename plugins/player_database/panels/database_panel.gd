# database_panel.gd —— 选手数据库二级面板。
# 挂载在 control_panel_base（slot="control_panel"），提供选手 / 解说 / 队伍的
# 增删改查、当前选中、JSON 导入导出。
# 集成约定：
#   - 读取 / 写入统一经本插件服务节点（组 player_database_service），不跨插件访问；
#   - 选中当前选手 / 解说时同时发出 now_player / now_announcer 组约定的
#     player_selected / announcer_selected 信号，PluginScene 据此刷新直播场景；
#   - 数据库写入后由服务导出 DataService 契约 JSON，其它插件继续经 DataService 读取。

extends VBoxContainer

signal player_selected(player_data: Dictionary)
signal announcer_selected(announcer_data: Dictionary)

const SERVICE_GROUP := &"player_database_service"
const PLAYER_SCENE_GROUP := &"plugin_scenes"

var _service: Node = null
var _tabs: TabContainer = null
var _status: Label = null
var _confirm: ConfirmationDialog = null

# 选手页
var _player_list: ItemList = null
var _player_ids: Array = []
var _player_fields: Dictionary = {}
var _player_team_option: OptionButton = null
var _player_captain: CheckBox = null
var _player_score: SpinBox = null
var _player_money: SpinBox = null
var _editing_player_id: String = ""

# 解说页
var _announcer_list: ItemList = null
var _announcer_ids: Array = []
var _announcer_fields: Dictionary = {}
var _editing_announcer_id: String = ""

# 队伍页
var _team_list: ItemList = null
var _team_ids: Array = []
var _team_fields: Dictionary = {}
var _team_captain: LineEdit = null
var _team_rank: LineEdit = null
var _team_balance: SpinBox = null
var _team_score: SpinBox = null
var _team_members: LineEdit = null
var _editing_team_id: String = ""

# 数据页
var _db_path_label: Label = null
var _stats_label: Label = null
var _csv_path_label: Label = null

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_group(&"now_player")
	add_to_group(&"now_announcer")
	_build_ui()
	_service = get_tree().get_first_node_in_group(SERVICE_GROUP)
	if _service == null:
		_set_status("数据库服务未就绪：请确认 player_database 插件已加载", true)
		return
	_refresh_all()
	call_deferred("_reconnect_live_scenes")

# ── UI 构建 ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	add_theme_constant_override("separation", 4)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	_build_players_tab()
	_build_announcers_tab()
	_build_teams_tab()
	_build_data_tab()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 34)
	_status.text = "就绪"
	add_child(_status)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "确认操作"
	add_child(_confirm)

func _add_tab(title: String, node_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = node_name
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	_tabs.add_child(margin)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)
	return box

func _build_players_tab() -> void:
	var box := _add_tab("选手", "Players")
	var list_row := HBoxContainer.new()
	list_row.custom_minimum_size = Vector2(0, 128)
	_player_list = ItemList.new()
	_player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player_list.item_selected.connect(_on_player_item_selected)
	list_row.add_child(_player_list)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.add_child(_button("新建", _on_player_new))
	buttons.add_child(_button("删除", _on_player_delete))
	buttons.add_child(_button("设为当前", _on_player_set_current))
	buttons.add_child(_button("取消当前", _on_player_clear_current))
	list_row.add_child(buttons)
	box.add_child(list_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	form.add_child(grid)
	_player_fields[DataKeys.PLAYER_ID] = _field(grid, "id")
	_player_fields[DataKeys.PLAYER_NAME] = _field(grid, "名称")
	grid.add_child(_label("队伍"))
	_player_team_option = OptionButton.new()
	_player_team_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_player_team_option)
	_player_fields[DataKeys.PLAYER_ICON_PATH] = _field(grid, "头像路径")
	_player_fields[DataKeys.PLAYER_STARTING_OPERATOR_CHOICE] = _field(grid, "开局干员")
	_player_fields[DataKeys.PLAYER_STARTING_RELIC_CHOICE] = _field(grid, "开局藏品")
	_player_fields[DataKeys.PLAYER_STARTING_SQUAD_CHOICE] = _field(grid, "开局分队")
	_player_fields[DataKeys.STATS_SLOGAN] = _field(grid, "感言")
	grid.add_child(_label("队长"))
	_player_captain = CheckBox.new()
	_player_captain.text = "是"
	grid.add_child(_player_captain)
	grid.add_child(_label("积分"))
	_player_score = _spin(grid)
	grid.add_child(_label("取钱"))
	_player_money = _spin(grid)
	var save := _button("保存选手", _on_player_save)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(save)

func _build_announcers_tab() -> void:
	var box := _add_tab("解说", "Announcers")
	var list_row := HBoxContainer.new()
	list_row.custom_minimum_size = Vector2(0, 150)
	_announcer_list = ItemList.new()
	_announcer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_announcer_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_announcer_list.item_selected.connect(_on_announcer_item_selected)
	list_row.add_child(_announcer_list)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.add_child(_button("新建", _on_announcer_new))
	buttons.add_child(_button("删除", _on_announcer_delete))
	buttons.add_child(_button("设为当前", _on_announcer_set_current))
	buttons.add_child(_button("取消当前", _on_announcer_clear_current))
	list_row.add_child(buttons)
	box.add_child(list_row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	_announcer_fields[DataKeys.ANNOUNCER_ID] = _field(grid, "id")
	_announcer_fields[DataKeys.ANNOUNCER_NAME] = _field(grid, "名称")
	_announcer_fields[DataKeys.ANNOUNCER_ICON_PATH] = _field(grid, "头像路径")
	var save := _button("保存解说", _on_announcer_save)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(save)

func _build_teams_tab() -> void:
	var box := _add_tab("队伍", "Teams")
	var list_row := HBoxContainer.new()
	list_row.custom_minimum_size = Vector2(0, 128)
	_team_list = ItemList.new()
	_team_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_team_list.item_selected.connect(_on_team_item_selected)
	list_row.add_child(_team_list)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.add_child(_button("新建", _on_team_new))
	buttons.add_child(_button("删除", _on_team_delete))
	list_row.add_child(buttons)
	box.add_child(list_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	form.add_child(grid)
	_team_fields[DataKeys.TEAM_ID] = _field(grid, "id")
	_team_fields[DataKeys.TEAM_NAME] = _field(grid, "名称")
	_team_fields[DataKeys.TEAM_ICON_PATH] = _field(grid, "图标路径")
	grid.add_child(_label("队长序号"))
	_team_captain = LineEdit.new()
	_team_captain.placeholder_text = "可空，整数"
	grid.add_child(_team_captain)
	grid.add_child(_label("排名"))
	_team_rank = LineEdit.new()
	_team_rank.placeholder_text = "可空，整数"
	grid.add_child(_team_rank)
	grid.add_child(_label("资金"))
	_team_balance = _spin(grid)
	grid.add_child(_label("积分"))
	_team_score = _spin(grid)
	grid.add_child(_label("成员"))
	_team_members = LineEdit.new()
	_team_members.editable = false
	_team_members.placeholder_text = "由选手的 team_id 自动派生"
	grid.add_child(_team_members)
	var save := _button("保存队伍", _on_team_save)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(save)

func _build_data_tab() -> void:
	var box := _add_tab("数据", "Data")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	scroll.add_child(inner)

	inner.add_child(_label("数据库文件"))
	_db_path_label = Label.new()
	_db_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_db_path_label)
	inner.add_child(_label("状态"))
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_stats_label)

	inner.add_child(HSeparator.new())
	inner.add_child(_label("JSON 契约同步"))
	inner.add_child(_button("从 JSON 导入（合并同名 id）", _on_import_json))
	inner.add_child(_button("导出到 JSON（覆盖契约文件）", _on_export_json))

	inner.add_child(HSeparator.new())
	inner.add_child(_label("CSV 快速录入（players.csv / teams.csv / announcers.csv）"))
	_csv_path_label = Label.new()
	_csv_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_csv_path_label)
	inner.add_child(_button("从 CSV 导入（合并）", _on_import_csv))
	inner.add_child(_button("导出 CSV 模板（表头）", _on_export_csv_template))
	inner.add_child(_button("导出当前数据为 CSV", _on_export_csv))
	inner.add_child(_button("打开 CSV 目录", _on_open_csv_dir))
	inner.add_child(_button("刷新状态", _refresh_stats))

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _field(grid: GridContainer, label_text: String) -> LineEdit:
	grid.add_child(_label(label_text))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(edit)
	return edit

func _spin(grid: GridContainer) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 99999999
	spin.step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(spin)
	return spin

# ── 选手操作 ─────────────────────────────────────────────────────────────────

func _on_player_item_selected(_index: int) -> void:
	var player_id := _selected_player_id()
	if player_id.is_empty() or _service == null:
		return
	var player = _service.call("get_player", player_id)
	if player is Dictionary and not player.is_empty():
		_fill_player(player)

func _on_player_new() -> void:
	_editing_player_id = ""
	_fill_player({})
	_set_status("新建选手：填写 id 与名称后保存")

func _on_player_save() -> void:
	if not _require_service():
		return
	var data := _collect_player()
	var result: Dictionary
	if _editing_player_id.is_empty():
		result = _service.call("create_player", data)
		if result.get("ok", false):
			_editing_player_id = str(data.get(DataKeys.PLAYER_ID, ""))
	else:
		result = _service.call("update_player", _editing_player_id, data)
	_after_player_write(result)

func _on_player_delete() -> void:
	if not _require_service():
		return
	var player_id := _editing_player_id if not _editing_player_id.is_empty() else _selected_player_id()
	if player_id.is_empty():
		_set_status("请先选择要删除的选手", true)
		return
	_ask_confirm("删除选手 %s？该操作不可撤销。" % player_id, func() -> void:
		var result: Dictionary = _service.call("delete_player", player_id)
		_after_player_write(result, true)
	)

func _on_player_set_current() -> void:
	if not _require_service():
		return
	var player_id := _editing_player_id if not _editing_player_id.is_empty() else _selected_player_id()
	if player_id.is_empty():
		_set_status("请先选择选手", true)
		return
	var result: Dictionary = _service.call("set_current_player", player_id)
	if result.get("ok", false):
		var player = _service.call("get_player", player_id)
		player_selected.emit(player if player is Dictionary else {})
		_set_status("当前选手已设为 %s" % player_id)
		_refresh_all()
		_select_player(player_id)
	else:
		_set_status(_format_result(result), true)

func _on_player_clear_current() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("clear_current_player")
	if result.get("ok", false):
		player_selected.emit({})
		_set_status("已取消当前选手")
		_refresh_all()
	else:
		_set_status(_format_result(result), true)

func _fill_player(player: Dictionary) -> void:
	_editing_player_id = str(player.get(DataKeys.PLAYER_ID, ""))
	_set_line(_player_fields[DataKeys.PLAYER_ID], _editing_player_id)
	_set_line(_player_fields[DataKeys.PLAYER_NAME], str(player.get(DataKeys.PLAYER_NAME, "")))
	_set_line(_player_fields[DataKeys.PLAYER_ICON_PATH], str(player.get(DataKeys.PLAYER_ICON_PATH, "")))
	_set_line(_player_fields[DataKeys.PLAYER_STARTING_OPERATOR_CHOICE], str(player.get(DataKeys.PLAYER_STARTING_OPERATOR_CHOICE, "")))
	_set_line(_player_fields[DataKeys.PLAYER_STARTING_RELIC_CHOICE], str(player.get(DataKeys.PLAYER_STARTING_RELIC_CHOICE, "")))
	_set_line(_player_fields[DataKeys.PLAYER_STARTING_SQUAD_CHOICE], str(player.get(DataKeys.PLAYER_STARTING_SQUAD_CHOICE, "")))
	var stats := {}
	if player.get(DataKeys.PLAYER_STATS) is Dictionary:
		stats = player.get(DataKeys.PLAYER_STATS)
	_set_line(_player_fields[DataKeys.STATS_SLOGAN], str(stats.get(DataKeys.STATS_SLOGAN, "")))
	_player_score.value = int(stats.get(DataKeys.STATS_SCORE, 0))
	_player_money.value = int(stats.get(DataKeys.STATS_MONEY_TAKEN, 0))
	_player_captain.button_pressed = int(player.get(DataKeys.PLAYER_CAPTAIN, 0)) != 0
	_select_team_option(str(player.get(DataKeys.PLAYER_TEAM_ID, "")))
	_player_fields[DataKeys.PLAYER_ID].editable = _editing_player_id.is_empty()

func _collect_player() -> Dictionary:
	return {
		DataKeys.PLAYER_ID: _player_fields[DataKeys.PLAYER_ID].text.strip_edges(),
		DataKeys.PLAYER_NAME: _player_fields[DataKeys.PLAYER_NAME].text.strip_edges(),
		DataKeys.PLAYER_TEAM_ID: _selected_team_id(),
		DataKeys.PLAYER_CAPTAIN: 1 if _player_captain.button_pressed else 0,
		DataKeys.PLAYER_ICON_PATH: _player_fields[DataKeys.PLAYER_ICON_PATH].text.strip_edges(),
		DataKeys.PLAYER_STARTING_OPERATOR_CHOICE: _player_fields[DataKeys.PLAYER_STARTING_OPERATOR_CHOICE].text.strip_edges(),
		DataKeys.PLAYER_STARTING_RELIC_CHOICE: _player_fields[DataKeys.PLAYER_STARTING_RELIC_CHOICE].text.strip_edges(),
		DataKeys.PLAYER_STARTING_SQUAD_CHOICE: _player_fields[DataKeys.PLAYER_STARTING_SQUAD_CHOICE].text.strip_edges(),
		DataKeys.PLAYER_STATS: {
			DataKeys.STATS_SCORE: int(_player_score.value),
			DataKeys.STATS_MONEY_TAKEN: int(_player_money.value),
			DataKeys.STATS_SLOGAN: _player_fields[DataKeys.STATS_SLOGAN].text.strip_edges(),
		},
	}

func _after_player_write(result: Dictionary, deleted: bool = false) -> void:
	if result.get("ok", false):
		var player_id: String = ""
		if not deleted:
			var result_data: Dictionary = result.get("data", {})
			var result_player: Dictionary = result_data.get("player", {})
			player_id = str(result_player.get(DataKeys.PLAYER_ID, ""))
		_set_status("已删除选手" if deleted else "选手已保存并同步契约 JSON")
		_refresh_all()
		if deleted:
			_editing_player_id = ""
			_fill_player({})
		elif not player_id.is_empty():
			_editing_player_id = player_id
			_select_player(player_id)
	else:
		_set_status(_format_result(result), true)

func _select_player(player_id: String) -> void:
	for i in _player_ids.size():
		if str(_player_ids[i]) == player_id:
			_player_list.select(i)
			var player = _service.call("get_player", player_id)
			if player is Dictionary:
				_fill_player(player)
			return

func _selected_player_id() -> String:
	var selected := _player_list.get_selected_items()
	return str(_player_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""

func _select_team_option(team_id: String) -> void:
	if _player_team_option == null:
		return
	for i in _player_team_option.item_count:
		if str(_player_team_option.get_item_metadata(i)) == team_id:
			_player_team_option.select(i)
			return
	_player_team_option.select(0)

func _selected_team_id() -> String:
	if _player_team_option == null or _player_team_option.selected < 0:
		return ""
	return str(_player_team_option.get_item_metadata(_player_team_option.selected))

# ── 解说操作 ─────────────────────────────────────────────────────────────────

func _on_announcer_item_selected(_index: int) -> void:
	var announcer_id := _selected_announcer_id()
	if announcer_id.is_empty() or _service == null:
		return
	var announcer = _service.call("get_announcer", announcer_id)
	if announcer is Dictionary and not announcer.is_empty():
		_fill_announcer(announcer)

func _on_announcer_new() -> void:
	_editing_announcer_id = ""
	_fill_announcer({})
	_set_status("新建解说：填写 id 与名称后保存")

func _on_announcer_save() -> void:
	if not _require_service():
		return
	var data := {
		DataKeys.ANNOUNCER_ID: _announcer_fields[DataKeys.ANNOUNCER_ID].text.strip_edges(),
		DataKeys.ANNOUNCER_NAME: _announcer_fields[DataKeys.ANNOUNCER_NAME].text.strip_edges(),
		DataKeys.ANNOUNCER_ICON_PATH: _announcer_fields[DataKeys.ANNOUNCER_ICON_PATH].text.strip_edges(),
	}
	var result: Dictionary
	if _editing_announcer_id.is_empty():
		result = _service.call("create_announcer", data)
		if result.get("ok", false):
			_editing_announcer_id = str(data.get(DataKeys.ANNOUNCER_ID, ""))
	else:
		result = _service.call("update_announcer", _editing_announcer_id, data)
	_after_announcer_write(result)

func _on_announcer_delete() -> void:
	if not _require_service():
		return
	var announcer_id := _editing_announcer_id if not _editing_announcer_id.is_empty() else _selected_announcer_id()
	if announcer_id.is_empty():
		_set_status("请先选择要删除的解说", true)
		return
	_ask_confirm("删除解说 %s？该操作不可撤销。" % announcer_id, func() -> void:
		var result: Dictionary = _service.call("delete_announcer", announcer_id)
		_after_announcer_write(result, true)
	)

func _on_announcer_set_current() -> void:
	if not _require_service():
		return
	var announcer_id := _editing_announcer_id if not _editing_announcer_id.is_empty() else _selected_announcer_id()
	if announcer_id.is_empty():
		_set_status("请先选择解说", true)
		return
	var result: Dictionary = _service.call("set_current_announcer", announcer_id)
	if result.get("ok", false):
		var announcer = _service.call("get_announcer", announcer_id)
		announcer_selected.emit(announcer if announcer is Dictionary else {})
		_set_status("当前解说已设为 %s" % announcer_id)
		_refresh_all()
		_select_announcer(announcer_id)
	else:
		_set_status(_format_result(result), true)

func _on_announcer_clear_current() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("clear_current_announcer")
	if result.get("ok", false):
		announcer_selected.emit({})
		_set_status("已取消当前解说")
		_refresh_all()
	else:
		_set_status(_format_result(result), true)

func _fill_announcer(announcer: Dictionary) -> void:
	_editing_announcer_id = str(announcer.get(DataKeys.ANNOUNCER_ID, ""))
	_set_line(_announcer_fields[DataKeys.ANNOUNCER_ID], _editing_announcer_id)
	_set_line(_announcer_fields[DataKeys.ANNOUNCER_NAME], str(announcer.get(DataKeys.ANNOUNCER_NAME, "")))
	_set_line(_announcer_fields[DataKeys.ANNOUNCER_ICON_PATH], str(announcer.get(DataKeys.ANNOUNCER_ICON_PATH, "")))
	_announcer_fields[DataKeys.ANNOUNCER_ID].editable = _editing_announcer_id.is_empty()

func _after_announcer_write(result: Dictionary, deleted: bool = false) -> void:
	if result.get("ok", false):
		_set_status("已删除解说" if deleted else "解说已保存并同步契约 JSON")
		_refresh_all()
		if deleted:
			_editing_announcer_id = ""
			_fill_announcer({})
		else:
			_select_announcer(_editing_announcer_id)
	else:
		_set_status(_format_result(result), true)

func _select_announcer(announcer_id: String) -> void:
	for i in _announcer_ids.size():
		if str(_announcer_ids[i]) == announcer_id:
			_announcer_list.select(i)
			var announcer = _service.call("get_announcer", announcer_id)
			if announcer is Dictionary:
				_fill_announcer(announcer)
			return

func _selected_announcer_id() -> String:
	var selected := _announcer_list.get_selected_items()
	return str(_announcer_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""

# ── 队伍操作 ─────────────────────────────────────────────────────────────────

func _on_team_item_selected(_index: int) -> void:
	var team_id := _selected_team_row_id()
	if team_id.is_empty() or _service == null:
		return
	var team = _service.call("get_team", team_id)
	if team is Dictionary and not team.is_empty():
		_fill_team(team)

func _on_team_new() -> void:
	_editing_team_id = ""
	_fill_team({})
	_set_status("新建队伍：填写 id 与名称后保存")

func _on_team_save() -> void:
	if not _require_service():
		return
	var data := _collect_team()
	var result: Dictionary
	if _editing_team_id.is_empty():
		result = _service.call("create_team", data)
		if result.get("ok", false):
			_editing_team_id = str(data.get(DataKeys.TEAM_ID, ""))
	else:
		result = _service.call("update_team", _editing_team_id, data)
	if result.get("ok", false):
		_set_status("队伍已保存并同步契约 JSON")
		_refresh_all()
		_select_team(_editing_team_id)
	else:
		_set_status(_format_result(result), true)

func _on_team_delete() -> void:
	if not _require_service():
		return
	var team_id := _editing_team_id if not _editing_team_id.is_empty() else _selected_team_row_id()
	if team_id.is_empty():
		_set_status("请先选择要删除的队伍", true)
		return
	_ask_confirm("删除队伍 %s？其选手的 team_id 将被清空。" % team_id, func() -> void:
		var result: Dictionary = _service.call("delete_team", team_id)
		if result.get("ok", false):
			_editing_team_id = ""
			_fill_team({})
			_set_status("已删除队伍，相关选手的队伍引用已清空")
			_refresh_all()
		else:
			_set_status(_format_result(result), true)
	)

func _fill_team(team: Dictionary) -> void:
	_editing_team_id = str(team.get(DataKeys.TEAM_ID, ""))
	_set_line(_team_fields[DataKeys.TEAM_ID], _editing_team_id)
	_set_line(_team_fields[DataKeys.TEAM_NAME], str(team.get(DataKeys.TEAM_NAME, "")))
	_set_line(_team_fields[DataKeys.TEAM_ICON_PATH], str(team.get(DataKeys.TEAM_ICON_PATH, "")))
	_team_captain.text = "" if team.get(DataKeys.TEAM_CAPTAIN) == null else str(team.get(DataKeys.TEAM_CAPTAIN))
	_team_rank.text = "" if team.get(DataKeys.TEAM_RANK) == null else str(team.get(DataKeys.TEAM_RANK))
	_team_balance.value = int(team.get(DataKeys.TEAM_BALANCE, 0))
	_team_score.value = int(team.get(DataKeys.TEAM_SCORE, 0))
	var members: Array = team.get(DataKeys.TEAM_MEMBERS, []) if team.get(DataKeys.TEAM_MEMBERS) is Array else []
	_team_members.text = ", ".join(members)
	_team_fields[DataKeys.TEAM_ID].editable = _editing_team_id.is_empty()

func _collect_team() -> Dictionary:
	return {
		DataKeys.TEAM_ID: _team_fields[DataKeys.TEAM_ID].text.strip_edges(),
		DataKeys.TEAM_NAME: _team_fields[DataKeys.TEAM_NAME].text.strip_edges(),
		DataKeys.TEAM_CAPTAIN: _parse_nullable_int(_team_captain.text),
		DataKeys.TEAM_RANK: _parse_nullable_int(_team_rank.text),
		DataKeys.TEAM_BALANCE: int(_team_balance.value),
		DataKeys.TEAM_SCORE: int(_team_score.value),
		DataKeys.TEAM_ICON_PATH: _team_fields[DataKeys.TEAM_ICON_PATH].text.strip_edges(),
	}

func _select_team(team_id: String) -> void:
	for i in _team_ids.size():
		if str(_team_ids[i]) == team_id:
			_team_list.select(i)
			var team = _service.call("get_team", team_id)
			if team is Dictionary:
				_fill_team(team)
			return

func _selected_team_row_id() -> String:
	var selected := _team_list.get_selected_items()
	return str(_team_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""

func _parse_nullable_int(text: String) -> Variant:
	var stripped := text.strip_edges()
	return null if stripped.is_empty() else int(stripped)

# ── 数据导入 / 导出 ──────────────────────────────────────────────────────────

func _on_import_json() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("import_from_json")
	var sync: Dictionary = _service.call("export_to_json")
	var counts: Dictionary = result.get("counts", {})
	_refresh_all()
	if result.get("ok", false) and sync.get("ok", false):
		_set_status("导入完成：选手 %d / 队伍 %d / 解说 %d" % [
			int(counts.get("players", 0)), int(counts.get("teams", 0)), int(counts.get("announcers", 0))
		])
	else:
		_set_status(_format_result(result if not result.get("ok", false) else sync), true)

func _on_export_json() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("export_to_json")
	_set_status("已导出到 userdata 契约 JSON" if result.get("ok", false) else _format_result(result), not result.get("ok", false))

func _on_import_csv() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("import_from_csv")
	_refresh_all()
	if result.get("ok", false):
		var counts: Dictionary = result.get("counts", {})
		_set_status("CSV 导入完成：选手 %d / 队伍 %d / 解说 %d（新建 %d）" % [
			int(counts.get("players", 0)), int(counts.get("teams", 0)),
			int(counts.get("announcers", 0)), int(counts.get("created", 0)),
		])
	else:
		_set_status(_format_result(result), true)

func _on_export_csv_template() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("ensure_csv_templates")
	if result.get("ok", false):
		var created: Array = result.get("created", [])
		_set_status("CSV 模板已就绪（新建 %d 个）：%s" % [created.size(), str(result.get("dir", ""))])
	else:
		_set_status(str(result.get("error", "生成模板失败")), true)
	_refresh_stats()

func _on_export_csv() -> void:
	if not _require_service():
		return
	var result: Dictionary = _service.call("export_to_csv")
	if result.get("ok", false):
		var counts: Dictionary = result.get("counts", {})
		_set_status("已导出 CSV：选手 %d / 队伍 %d / 解说 %d" % [
			int(counts.get("players", 0)), int(counts.get("teams", 0)), int(counts.get("announcers", 0)),
		])
	else:
		_set_status(str(result.get("error", "导出 CSV 失败")), true)

func _on_open_csv_dir() -> void:
	if not _require_service():
		return
	var dir := str(_service.call("get_csv_dir"))
	if not DirAccess.dir_exists_absolute(dir):
		if DirAccess.make_dir_recursive_absolute(dir) != OK:
			_set_status("无法创建 CSV 目录: %s" % dir, true)
			return
	var err := OS.shell_open(dir)
	var message := ("已打开 CSV 目录: %s" % dir) if err == OK else ("打开目录失败: %s" % dir)
	_set_status(message, err != OK)

# ── 刷新 / 状态 ───────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	if _service == null:
		return
	_refresh_players()
	_refresh_announcers()
	_refresh_teams()
	_rebuild_team_options(_selected_team_id())
	_refresh_stats()

func _refresh_players() -> void:
	var current = _service.call("get_current_player")
	var current_id := str(current.get(DataKeys.PLAYER_ID, "")) if current is Dictionary else ""
	_player_ids.clear()
	_player_list.clear()
	for player in _service.call("list_players"):
		if not (player is Dictionary):
			continue
		var player_id := str(player.get(DataKeys.PLAYER_ID, ""))
		_player_ids.append(player_id)
		var prefix := "▶ " if player_id == current_id else ""
		_player_list.add_item("%s%s  (%s)" % [prefix, str(player.get(DataKeys.PLAYER_NAME, "")), player_id])
		_player_list.set_item_metadata(_player_list.item_count - 1, player_id)

func _refresh_announcers() -> void:
	var current = _service.call("get_current_announcer")
	var current_id := str(current.get(DataKeys.ANNOUNCER_ID, "")) if current is Dictionary else ""
	_announcer_ids.clear()
	_announcer_list.clear()
	for announcer in _service.call("list_announcers"):
		if not (announcer is Dictionary):
			continue
		var announcer_id := str(announcer.get(DataKeys.ANNOUNCER_ID, ""))
		_announcer_ids.append(announcer_id)
		var prefix := "▶ " if announcer_id == current_id else ""
		_announcer_list.add_item("%s%s  (%s)" % [prefix, str(announcer.get(DataKeys.ANNOUNCER_NAME, "")), announcer_id])
		_announcer_list.set_item_metadata(_announcer_list.item_count - 1, announcer_id)

func _refresh_teams() -> void:
	_team_ids.clear()
	_team_list.clear()
	for team in _service.call("list_teams"):
		if not (team is Dictionary):
			continue
		var team_id := str(team.get(DataKeys.TEAM_ID, ""))
		_team_ids.append(team_id)
		_team_list.add_item("%s  (%s)" % [str(team.get(DataKeys.TEAM_NAME, "")), team_id])
		_team_list.set_item_metadata(_team_list.item_count - 1, team_id)

func _rebuild_team_options(keep_team_id: String) -> void:
	_player_team_option.clear()
	_player_team_option.add_item("（无队伍）")
	_player_team_option.set_item_metadata(0, "")
	var index := 1
	for team in _service.call("list_teams"):
		if not (team is Dictionary):
			continue
		var team_id := str(team.get(DataKeys.TEAM_ID, ""))
		_player_team_option.add_item("%s · %s" % [team_id, str(team.get(DataKeys.TEAM_NAME, ""))])
		_player_team_option.set_item_metadata(index, team_id)
		index += 1
	_select_team_option(keep_team_id)

func _refresh_stats() -> void:
	if _service == null:
		return
	var stats = _service.call("get_stats")
	if not (stats is Dictionary):
		return
	_db_path_label.text = str(stats.get("db_path", ""))
	if _csv_path_label != null:
		_csv_path_label.text = str(_service.call("get_csv_dir"))
	_stats_label.text = "选手 %d · 队伍 %d · 解说 %d\n当前选手：%s\n当前解说：%s" % [
		int(stats.get("players", 0)),
		int(stats.get("teams", 0)),
		int(stats.get("announcers", 0)),
		str(stats.get("current_player_id", "")),
		str(stats.get("current_announcer_id", "")),
	]

# ── 通用辅助 ─────────────────────────────────────────────────────────────────

func _require_service() -> bool:
	if _service == null:
		_set_status("数据库服务未就绪：请确认 player_database 插件已加载", true)
		return false
	return true

func _set_line(edit: LineEdit, text: String) -> void:
	edit.text = text

func _set_status(text: String, is_error: bool = false) -> void:
	if _status == null:
		return
	_status.text = text
	_status.modulate = Color(1.0, 0.55, 0.55) if is_error else Color(1, 1, 1)

func _format_result(result: Dictionary) -> String:
	var message := str(result.get("error", "操作失败"))
	var issues = result.get("issues", [])
	if issues is Array and not issues.is_empty():
		var shown: Array[String] = []
		for i in mini(3, issues.size()):
			shown.append(str(issues[i]))
		message += "：" + "；".join(shown)
	return message

func _ask_confirm(message: String, callback: Callable) -> void:
	_confirm.dialog_text = message
	for connection in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(connection.callable)
	_confirm.confirmed.connect(callback, CONNECT_ONE_SHOT)
	_confirm.popup_centered()

## 面板（重新）就绪后，让现有直播场景重新连接 now_player / now_announcer 组，
## 并补发当前选中，覆盖热重载或启动顺序导致场景先于面板 _ready 的情况。
func _reconnect_live_scenes() -> void:
	if _service == null or get_tree() == null:
		return
	get_tree().call_group(PLAYER_SCENE_GROUP, "_delayed_connect")
	var player = _service.call("get_current_player")
	if player is Dictionary and not player.is_empty():
		player_selected.emit(player)
	var announcer = _service.call("get_current_announcer")
	if announcer is Dictionary and not announcer.is_empty():
		announcer_selected.emit(announcer)
