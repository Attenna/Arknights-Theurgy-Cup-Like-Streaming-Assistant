# 冷水坑_3 文件结构精简汇总

## 一、删除的空 / 无引用文件（20 个）

### 空占位场景（仅含空 Node2D，无脚本无子节点）
| 文件 | 原因 |
|------|------|
| `scene/switch_clip.tscn` | 空 Node2D，无任何引用 |
| `scene/ui/score_board.tscn` | 空 Node2D，无任何引用 |
| `scene/ui/player_info.tscn` | 空 Node2D，无任何引用 |
| `scene/output_window.tscn` | 无引用，且脚本引用了不存在的 `/root/Main/OutputViewport`，废弃实验代码 |

### 无引用的 stream 场景（无任何 preload/load 加载）
| 文件 | 原因 |
|------|------|
| `scene/stream/PlayerBanner.tscn` | 无引用 |
| `scene/stream/StagePlayerInfo.tscn` | 无引用 |
| `scene/stream/PlayerVSOverlay.tscn` | 无引用 |

### 孤儿脚本（引用者已删除或从未被实例化）
| 文件 | 原因 |
|------|------|
| `scripts/output_window.gd` (+.uid) | 唯一引用者 output_window.tscn 已删 |
| `scripts/stream/PlayerVSOverlay.cs` (+.uid) | 唯一引用者 PlayerVSOverlay.tscn 已删 |
| `scripts/CommentatorName.cs` (+.uid) | 空桩（_Ready/_Process 均空），无场景引用 |
| `scripts/CommentatorInfoDisplay.cs` (+.uid) | 实现了 DisplayCommentator 但从未被任何场景实例化，旧解说面板 |
| `scripts/PlayerInfoDisplay.cs` (+.uid) | 从未被实例化；control_panel.gd 注释明确标注「左侧 Player Info 面板已废弃」，改用 carousel 体系 |
| `scripts/scene_manager.gd` (+.uid) | 拓扑死层（见下） |

### 孤儿 uid 文件
| 文件 | 原因 |
|------|------|
| `scene/label.gd.uid` | 实际 label.gd 位于 scripts/，此处无对应 .gd；uid 也与 main_vision.tscn 引用的 uid 不符，历史残留 |

## 二、拓扑逻辑纠错

### 1. 移除死掉的 SceneManager 间接层
- **问题**：`scene_manager.gd` 挂在 `control_panel.tscn` 的 `SceneManager` 节点上，定义了 `transition_requested` 信号与 `request_transition()` 方法。但 `control_panel.gd` 仅 `get_node_or_null("SceneManager")` 后打印 "SceneManager found" 就丢弃；其信号从未连接、方法从未调用。场景切换实际由 `main.gd` 直接连 `control_panel` 的 `scene_selected` 信号完成。
- **修复**：
  - 删除 `scripts/scene_manager.gd`(+.uid)
  - 从 `scene/ui/control_panel.tscn` 移除 ext_resource 与 SceneManager 节点，load_steps 4→3
  - 从 `scripts/control_panel.gd` 移除死查找代码

### 2. 让 tournament_status.tscn 自包含
- **问题**：`main.gd` 用 `win.set_script(load("...tournament_status.gd"))` 运行时挂脚本，反模式，场景不自描述。
- **修复**：在 `scene/ui/tournament_status.tscn` 直接挂脚本（load_steps 1→2），删除 `main.gd` 中的 `set_script` 调用。

## 三、可读性增强
- 清除全部孤儿 .uid 与空场景后，目录树与引用图一一对应，无悬空节点。
- 全部 4 个改动文件 lint 0 报错。
- 全仓搜索确认：无任何残留引用指向已删除文件。

## 四、引用图（精简后，全部可达）

```
Main.tscn (入口, project.godot)
├─ main.gd
│   ├─ main_vision.tscn ── countdown.gdshader, label.gd
│   ├─ streaming_arena.tscn ── player_avatar.tscn→PlayerAvatarDisplay.cs
│   │   │                        PlayerNickname.cs, TeamAvatar.cs, TeamName.cs
│   │   └─                      OperatorAvatar.cs→OperatorAvatarLoader.cs, OperatorName.cs
│   ├─ waiting_scene.tscn ── 方胜纹.gdshader, info_carousel.tscn→info_carousel.gd
│   │                                                     ├─ carousel_player_page.tscn
│   │                                                     │   ├─ carousel_player_page.gd
│   │                                                     │   ├─ PlayerImageField.tscn→PlayerImageField.cs
│   │                                                     │   ├─ PlayerFieldLabel.tscn→PlayerFieldLabel.cs
│   │                                                     │   └─ OperatorAvatar.cs
│   │                                                     └─ carousel_rank_page.tscn→carousel_rank_page.gd→TournamentApiClient.cs
│   ├─ ED.tscn ── 方胜纹.gdshader
│   ├─ PK.tscn ── player_avatar.tscn, PlayerNickname.cs
│   ├─ tournament_status.tscn ── tournament_status.gd → TournamentApiClient.cs
│   └─ control_panel.tscn ── control_panel.gd, PlayerSelector.cs
│                                                  └─ PlayerPreviewPanel.tscn
│                                                      ├─ PlayerPreviewPanel.cs
│                                                      └─ StreamPlayerCard.tscn
│                                                          ├─ StreamPlayerCard.cs
│                                                          └─ OperatorAvatar.cs
├─ PlayerApiClient.cs
├─ PlayerManager.cs
├─ CommentatorManager.cs
└─ AvatarLoader.cs
```

## 五、数量变化
- 场景 `.tscn`：23 → 16（删 7）
- 脚本 `.cs/.gd`：30 → 24（删 6）
- 孤儿 `.uid`：清理 13 个
- 根目录空目录 `data/`、`ui/`：未删除（已被用户拒绝，且 git 本不跟踪空目录）

## 六、未触碰（按要求）
- `assets/` 全部内容
- `shaders/`（2 个 gdshader 均被引用，健康）
- 根目录 `冷水坑_3.csproj.old`、`冷水坑#3.sln` 等构建文件残留（非场景/脚本拓扑范畴，留待用户决定）
