# tests/test_integration.gd
# 协作集成测试（issue #6）：测试插件对（mods/_test_pair_*）纯 EventBus 协作闭环。
# 断言：插件对随内核启动加载并完成协作收发；热重载 N 次后订阅数守恒
# （owner 清理证明，ADR-0002）；依赖阻塞不加载 + 依赖就绪后补加载。
# 运行于真实启动场景（tests/test_main.tscn），run() 内含 await，runner 统一 await 调用。

extends TestCase

const PAIR_A := "test_pair_a"
const PAIR_B := "test_pair_b"
const RELOAD_TIMES := 3

func run() -> bool:
	_test_pair_loaded()
	await _test_collaboration()
	await _test_reload_subscription_conserved()
	_test_blocked_plugin()
	return summary("test_integration")

# ── 环境访问（测试特权：直读内核组与 EventBus 内部订阅表） ────────────────────

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _kernel() -> Node:
	return _tree().get_nodes_in_group(PluginContext.KERNEL_GROUP)[0]

func _pm() -> Node:
	return _kernel().plugin_manager

## 统计 EventBus 内部订阅表中指定事件、指定 owner 的条目数（订阅守恒断言依据）。
func _subs_for(event: StringName, owner: StringName) -> int:
	var count := 0
	for sub in _kernel().event_bus._subs.get(event, []):
		if sub.get("owner", &"") == owner:
			count += 1
	return count

## 等两帧：确保 deferred 调用（插件自启动闭环的 ping）已 flush。
func _settle() -> void:
	await _tree().process_frame
	await _tree().process_frame

# ── 用例 ─────────────────────────────────────────────────────────────────────

func _test_pair_loaded() -> void:
	ok(_pm().is_loaded(PAIR_A), "测试插件对 A 随内核启动加载")
	ok(_pm().is_loaded(PAIR_B), "测试插件对 B 随内核启动加载")

func _test_collaboration() -> void:
	await _settle()
	var a: Node = _pm().get_plugin_instance(PAIR_A)
	ok(a != null and int(a.pong_count) >= 1, "纯 EventBus 协作闭环成立（A 收到 B 的 pong）")

func _test_reload_subscription_conserved() -> void:
	var pm := _pm()
	# 基线：各 owner 订阅恰 1 条
	eq(_subs_for(EventCatalog.TEST_PAIR_PINGED, &"test_pair_b"), 1, "基线：B 的 ping 订阅恰 1 条")
	eq(_subs_for(EventCatalog.TEST_PAIR_PONGED, &"test_pair_a"), 1, "基线：A 的 pong 订阅恰 1 条")
	# 热重载 B N 次：旧订阅被 unsubscribe_all 清理、新订阅重建，总数守恒（无悬空）
	for i in RELOAD_TIMES:
		pm.reload_plugin(PAIR_B)
	eq(_subs_for(EventCatalog.TEST_PAIR_PINGED, &"test_pair_b"), 1,
		"热重载 B %d 次后 ping 订阅守恒" % RELOAD_TIMES)
	# 热重载 A N 次：每次重载后自启动闭环恢复，新实例恰收到 N 个 pong
	for i in RELOAD_TIMES:
		pm.reload_plugin(PAIR_A)
	eq(_subs_for(EventCatalog.TEST_PAIR_PONGED, &"test_pair_a"), 1,
		"热重载 A %d 次后 pong 订阅守恒" % RELOAD_TIMES)
	await _settle()
	var a: Node = pm.get_plugin_instance(PAIR_A)
	eq(int(a.pong_count), RELOAD_TIMES,
		"热重载 A %d 次后闭环恢复（新实例收到 N 个 pong）" % RELOAD_TIMES)
	# 全量重载（F5 路径）：闭环与订阅双守恒
	pm.reload_all()
	await _settle()
	a = pm.get_plugin_instance(PAIR_A)
	eq(int(a.pong_count), 1, "reload_all 后闭环恢复")
	eq(_subs_for(EventCatalog.TEST_PAIR_PINGED, &"test_pair_b"), 1, "reload_all 后 B 订阅守恒")
	eq(_subs_for(EventCatalog.TEST_PAIR_PONGED, &"test_pair_a"), 1, "reload_all 后 A 订阅守恒")

func _test_blocked_plugin() -> void:
	var pm := _pm()
	var mods := DirAccess.open("res://mods")
	# 阶段 1：动态创建缺失依赖的插件 → 重走发现流程 → 阻塞不加载
	mods.make_dir("_test_blocking")
	_write_json("res://mods/_test_blocking/plugin.json", {
		"id": "test_blocking",
		"name": "阻塞测试插件",
		"version": "1.0.0",
		"api_version": "2.0.0",
		"dependencies": ["missing_dep_xyz"],
		"hot_reload": { "enabled": false },
	})
	_rediscover(pm)
	ok(not pm.is_loaded("test_blocking"), "缺失依赖的插件不被加载")
	var blocked_ids := PackedStringArray()
	for b in pm.get_blocked_plugins():
		blocked_ids.append(str(b.get("id", "")))
	ok(blocked_ids.has("test_blocking"), "阻塞列表记录缺失依赖插件")
	# 阶段 2：补上缺失依赖（模拟用户放置依赖插件目录）→ 走 reload_all 尾部的补加载路径
	mods.make_dir("_missing_dep_xyz")
	_write_json("res://mods/_missing_dep_xyz/plugin.json", {
		"id": "missing_dep_xyz",
		"name": "补依赖测试插件",
		"version": "1.0.0",
		"api_version": "2.0.0",
		"dependencies": [],
		"hot_reload": { "enabled": false },
	})
	pm._load_plugin("res://mods/_missing_dep_xyz", {
		"id": "missing_dep_xyz", "dependencies": [],
	}, "res://mods", true)
	pm._try_load_blocked()
	ok(pm.is_loaded("missing_dep_xyz"), "补上的依赖插件已加载")
	ok(pm.is_loaded("test_blocking"), "依赖就绪后阻塞插件补加载成功（_try_load_blocked）")
	# 清理动态目录，保持工作区干净（测试进程随后退出）
	eq(DirAccess.remove_absolute("res://mods/_test_blocking/plugin.json"), OK, "清理阻塞测试插件清单")
	eq(DirAccess.remove_absolute("res://mods/_test_blocking"), OK, "清理阻塞测试插件目录")
	eq(DirAccess.remove_absolute("res://mods/_missing_dep_xyz/plugin.json"), OK, "清理依赖插件清单")
	eq(DirAccess.remove_absolute("res://mods/_missing_dep_xyz"), OK, "清理依赖插件目录")

## 重走插件发现流程：重扫描 mods → 依赖重解析 → 加载新出现的插件（已加载者跳过）。
## 模拟"重启后的发现"，用于动态创建插件目录后的加载验证。
func _rediscover(pm: Node) -> void:
	var manifests: Array = pm._scan_manifests("res://mods")
	var ordered: Array = pm._resolve_load_order(manifests)
	for info in ordered:
		var pid := str(info.get("manifest", {}).get("id", str(info.get("res_dir", "")).get_file()))
		if not pm.is_loaded(pid):
			pm._load_plugin(str(info.get("res_dir", "")), info.get("manifest", {}), str(info.get("origin", "")))

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "    "))
	f.close()
