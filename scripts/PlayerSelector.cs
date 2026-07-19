using Godot;
using System.Collections.Generic;

namespace PlayerStatistics
{
    public partial class PlayerSelector : VBoxContainer
    {
        [Export] public string PlayerManagerPath = "/root/Main/PlayerManager";
        [Export] public string CommentatorManagerPath = "/root/Main/CommentatorManager";
        [Export] public string PlayerApiClientPath = "/root/Main/PlayerApiClient";
        [Export] public string AvatarLoaderPath = "/root/Main/AvatarLoader";

        [Signal]
        public delegate void PlayerSelectedEventHandler(int playerId);

        [Signal]
        public delegate void CommentatorSelectedEventHandler(int commentatorId);

        [Signal]
        public delegate void LoginStatusChangedEventHandler(bool loggedIn);

        private PlayerManager _playerManager;
        private CommentatorManager _commentatorManager;
        private PlayerApiClient _playerApiClient;
        private LineEdit _searchInput;
        private Button _selectPlayerBtn;
        private Button _selectCommentatorBtn;
        private ItemList _playerList;
        private Button _selectBtn;
        private Button _redStageBtn;
        private Button _blueStageBtn;
        private LineEdit _usernameInput;
        private LineEdit _passwordInput;
        private Button _loginBtn;
        private Button _loadCacheBtn;
        private Label _loginStatusLabel;
        private bool _isPlayerMode = true;
        private bool _isLoggedIn = false;
        private List<int> _playerIdList = new List<int>();
        private int _selectedPlayerId = -1;
        private int _stagedRedPlayerId = -1;
        private int _stagedBluePlayerId = -1;
        private PlayerPreviewPanel _previewPanel;

        public override void _Ready()
        {
            _searchInput = GetNodeOrNull<LineEdit>("SearchInput");
            _selectPlayerBtn = GetNodeOrNull<Button>("ModeButtons/SelectPlayerBtn");
            _selectCommentatorBtn = GetNodeOrNull<Button>("ModeButtons/SelectCommentatorBtn");
            _playerList = GetNodeOrNull<ItemList>("PlayerListContainer/PlayerList");
            _selectBtn = GetNodeOrNull<Button>("PlayerInfoContainer/SelectBtn");
            _redStageBtn = GetNodeOrNull<Button>("PlayerInfoContainer/StageButtons/RedStageBtn");
            _blueStageBtn = GetNodeOrNull<Button>("PlayerInfoContainer/StageButtons/BlueStageBtn");

            GD.Print("[PlayerSelector] _Ready() - SearchInput: ", _searchInput != null);
            GD.Print("[PlayerSelector] _Ready() - SelectPlayerBtn: ", _selectPlayerBtn != null);
            GD.Print("[PlayerSelector] _Ready() - SelectCommentatorBtn: ", _selectCommentatorBtn != null);
            GD.Print("[PlayerSelector] _Ready() - PlayerList: ", _playerList != null);
            GD.Print("[PlayerSelector] _Ready() - SelectBtn: ", _selectBtn != null);
            GD.Print("[PlayerSelector] _Ready() - RedStageBtn: ", _redStageBtn != null);
            GD.Print("[PlayerSelector] _Ready() - BlueStageBtn: ", _blueStageBtn != null);

            FindLoginNodes();

            // 预填默认同步账号（仅在用户尚未手动输入时）：用户名 Endmin、密码 Astrid258。
            if (_usernameInput != null && string.IsNullOrEmpty(_usernameInput.Text))
            {
                _usernameInput.Text = PlayerApiClient.DefaultSyncUsername;
            }
            if (_passwordInput != null && string.IsNullOrEmpty(_passwordInput.Text))
            {
                _passwordInput.Text = PlayerApiClient.DefaultSyncPassword;
            }

            if (_searchInput != null)
            {
                _searchInput.TextChanged += OnSearchTextChanged;
            }

            if (_selectPlayerBtn != null)
            {
                _selectPlayerBtn.Pressed += OnSelectPlayerPressed;
                _selectPlayerBtn.ToggleMode = true;
                _selectPlayerBtn.ButtonPressed = true;
            }

            if (_selectCommentatorBtn != null)
            {
                _selectCommentatorBtn.Pressed += OnSelectCommentatorPressed;
                _selectCommentatorBtn.ToggleMode = true;
            }

            if (_playerList != null)
            {
                _playerList.ItemSelected += OnPlayerListItemSelected;
            }

            if (_selectBtn != null)
            {
                _selectBtn.Pressed += OnSelectBtnPressed;
            }

            if (_redStageBtn != null)
            {
                _redStageBtn.Pressed += () => OnStageBtnPressed("Red");
            }

            if (_blueStageBtn != null)
            {
                _blueStageBtn.Pressed += () => OnStageBtnPressed("Blue");
            }

            if (_loginBtn != null)
            {
                _loginBtn.Pressed += OnLoginPressed;
            }

            if (_loadCacheBtn != null)
            {
                _loadCacheBtn.Pressed += OnLoadCachePressed;
            }

            if (_passwordInput != null)
            {
                _passwordInput.AddThemeConstantOverride("echo_mode", 2);
                _passwordInput.GuiInput += OnPasswordGuiInput;
            }

            CallDeferred("ConnectManagers");
        }

        private void FindLoginNodes()
        {
            var window = FindControlPanel();
            if (window != null)
            {
                var loginSection = window.GetNodeOrNull<VBoxContainer>(
                    "MarginContainer/ScrollContainer/VBoxContainer/LoginSection");
                if (loginSection != null)
                {
                    _usernameInput = loginSection.GetNodeOrNull<LineEdit>("UsernameInput");
                    _passwordInput = loginSection.GetNodeOrNull<LineEdit>("PasswordInput");
                    _loginBtn = loginSection.GetNodeOrNull<Button>("LoginBtn");
                    _loadCacheBtn = loginSection.GetNodeOrNull<Button>("LoadCacheBtn");
                    _loginStatusLabel = loginSection.GetNodeOrNull<Label>("LoginStatusLabel");
                }
            }
        }

        private void ConnectManagers()
        {
            _playerManager = GetNodeOrNull<PlayerManager>(PlayerManagerPath);
            _commentatorManager = GetNodeOrNull<CommentatorManager>(CommentatorManagerPath);
            _playerApiClient = GetNodeOrNull<PlayerApiClient>(PlayerApiClientPath);

            if (_playerManager == null)
            {
                _playerManager = GetTree().Root.GetNodeOrNull<PlayerManager>("Main/PlayerManager");
                GD.Print($"[PlayerSelector] Fallback to Main/PlayerManager: {_playerManager != null}");
            }
            if (_playerApiClient == null)
            {
                _playerApiClient = GetTree().Root.GetNodeOrNull<PlayerApiClient>("Main/PlayerApiClient");
                GD.Print($"[PlayerSelector] Fallback to Main/PlayerApiClient: {_playerApiClient != null}");
            }

            GD.Print($"[PlayerSelector] Managers - PlayerManager: {_playerManager != null}, PlayerApiClient: {_playerApiClient != null}, PlayerList: {_playerList != null}");

            if (_playerApiClient != null)
            {
                _playerApiClient.LoadFailed += OnLoadFailed;
                _playerApiClient.players_loaded += OnPlayersLoadedFromApi;
                if (_playerApiClient.HasCredentials())
                {
                    SetLoggedIn(true);
                    SetLoginStatus("Auto-syncing...", false);
                    _playerApiClient.FetchPlayers();
                }
            }

            if (_playerManager != null)
            {
                _playerManager.PlayersUpdated += OnPlayersUpdated;
                UpdatePlayerList();

                if (!_isLoggedIn && _playerManager.Players.Count > 0)
                {
                    SetLoginStatus($"Loaded {_playerManager.Players.Count} players from cache", true);
                }
            }
            else
            {
                GD.PrintErr("[PlayerSelector] PlayerManager NOT FOUND at path: " + PlayerManagerPath);
            }

            if (_commentatorManager != null)
            {
                _commentatorManager.CommentatorsUpdated += OnCommentatorsUpdated;
            }

            // 监听控制面板的「清除上台」信号，同步重置本地已存上台 id，
            // 避免清除后被 RefreshStageDisplays() 的残留 id 重新 emit 回台上。
            var cpWindow = FindControlPanel();
            if (cpWindow != null && cpWindow.HasSignal("stage_clear"))
            {
                cpWindow.Connect("stage_clear", Callable.From((string side) => OnStageCleared(side)));
            }

            EnsurePreviewPanel();
        }

        // Walks up the tree to find the owning Window (the CtrlPanel). More reliable than
        // GetWindow() in embedded-window setups.
        private Window FindControlPanel()
        {
            Node n = this;
            while (n != null)
            {
                if (n is Window w)
                    return w;
                n = n.GetParent();
            }
            return null;
        }

        private void OnPasswordGuiInput(InputEvent @event)
        {
            if (@event is InputEventKey keyEvent && !keyEvent.Echo)
            {
                if (keyEvent.Keycode == Key.Enter)
                {
                    OnLoginPressed();
                }
            }
        }

        private void OnLoginPressed()
        {
            GD.Print("[PlayerSelector] OnLoginPressed() called");
            GD.Print("[PlayerSelector] PlayerApiClient: ", _playerApiClient != null);
            GD.Print("[PlayerSelector] UsernameInput: ", _usernameInput != null);
            GD.Print("[PlayerSelector] PasswordInput: ", _passwordInput != null);

            if (_playerApiClient == null)
            {
                GD.PrintErr("[PlayerSelector] PlayerApiClient is NULL!");
                return;
            }
            if (_usernameInput == null || _passwordInput == null)
            {
                GD.PrintErr("[PlayerSelector] UsernameInput or PasswordInput is NULL!");
                return;
            }

            string username = _usernameInput.Text;
            string password = _passwordInput.Text;

            if (string.IsNullOrEmpty(username) || string.IsNullOrEmpty(password))
            {
                SetLoginStatus("Please enter username and password", false);
                return;
            }

            SetLoginStatus("Logging in...", false);
            _playerApiClient.SetCredentials(username, password);
            _playerApiClient.FetchPlayers();
            GD.Print("[PlayerSelector] FetchPlayers() called");
        }

        private void OnLoadFailed(string error)
        {
            SetLoginStatus($"Sync failed: {error}", false);
        }

        private void SetLoggedIn(bool loggedIn)
        {
            _isLoggedIn = loggedIn;
            SetLoginStatus(loggedIn ? "Logged in" : "Not logged in", loggedIn);
            EmitSignal("login_status_changed", loggedIn);
        }

        private void SetLoginStatus(string message, bool success)
        {
            if (_loginStatusLabel != null)
            {
                _loginStatusLabel.Text = message;
                _loginStatusLabel.AddThemeColorOverride("font_color", success ? new Color(0, 1, 0) : new Color(1, 0, 0));
            }
        }

        private void OnSearchTextChanged(string text)
        {
            UpdatePlayerList();
        }

        private void OnSelectPlayerPressed()
        {
            if (_selectPlayerBtn != null && !_selectPlayerBtn.ButtonPressed)
            {
                _selectPlayerBtn.ButtonPressed = true;
            }
            _isPlayerMode = true;
            if (_selectCommentatorBtn != null)
            {
                _selectCommentatorBtn.ButtonPressed = false;
            }
            UpdatePlayerList();
            ClearSelection();
        }

        private void OnSelectCommentatorPressed()
        {
            if (_selectCommentatorBtn != null && !_selectCommentatorBtn.ButtonPressed)
            {
                _selectCommentatorBtn.ButtonPressed = true;
            }
            _isPlayerMode = false;
            if (_selectPlayerBtn != null)
            {
                _selectPlayerBtn.ButtonPressed = false;
            }
            UpdatePlayerList();
            ClearSelection();
        }

        private void OnPlayerListItemSelected(long index)
        {
            int idx = (int)index;
            if (idx >= 0 && idx < _playerIdList.Count)
            {
                _selectedPlayerId = _playerIdList[idx];
                UpdatePreview();
                if (_selectBtn != null)
                {
                    _selectBtn.Disabled = false;
                }
                if (_redStageBtn != null)
                {
                    _redStageBtn.Disabled = false;
                }
                if (_blueStageBtn != null)
                {
                    _blueStageBtn.Disabled = false;
                }
            }
        }

        private void OnSelectBtnPressed()
        {
            if (_selectedPlayerId <= 0) return;

            if (_isPlayerMode)
            {
                if (_playerManager != null)
                {
                    _playerManager.SelectPlayerById(_selectedPlayerId);
                }
                EmitSignal("player_selected", _selectedPlayerId);
                GD.Print($"[PlayerSelector] Selected active player: {_selectedPlayerId}");
            }
            else
            {
                if (_commentatorManager != null)
                {
                    _commentatorManager.SelectCommentatorById(_selectedPlayerId);
                }
                EmitSignal("commentator_selected", _selectedPlayerId);
                GD.Print($"[PlayerSelector] Selected commentator: {_selectedPlayerId}");
            }
        }

        private void OnStageBtnPressed(string side)
        {
            if (_selectedPlayerId <= 0)
            {
                GD.PrintErr("[PlayerSelector] OnStageBtnPressed: no player selected (_selectedPlayerId <= 0)");
                return;
            }
            if (!_isPlayerMode) return;

            if (_playerManager?.GetPlayerDictionary(_selectedPlayerId) == null)
            {
                GD.PrintErr($"[PlayerSelector] OnStageBtnPressed: GetPlayerDictionary returned null for id {_selectedPlayerId}");
                return;
            }

            if (side == "Red")
                _stagedRedPlayerId = _selectedPlayerId;
            else
                _stagedBluePlayerId = _selectedPlayerId;

            // 单一出口：把上台事件交给 main.gd 统一协调（更新场景头像 + 控制面板卡片）。
            var window = FindControlPanel();
            if (window != null && window.HasSignal("stage_player"))
            {
                window.EmitSignal("stage_player", _selectedPlayerId, side);
            }
            else
            {
                GD.PrintErr("[PlayerSelector] OnStageBtnPressed: control panel window / stage_player signal not available");
            }

            GD.Print($"[PlayerSelector] Staged player {_selectedPlayerId} to {side} stage");
        }

        // 控制面板「清除上台」时，同步清空本地保存的已上台 id。
        // 否则清除后，下一次玩家数据同步 RefreshStageDisplays() 会用这份残留 id
        // 重新 emit stage_player，把已清掉的选手又自动放回台上。
        private void OnStageCleared(string side)
        {
            if (side == "Red")
                _stagedRedPlayerId = -1;
            else if (side == "Blue")
                _stagedBluePlayerId = -1;
        }

        private void ClearSelection()
        {
            _selectedPlayerId = -1;
            _previewPanel?.Clear();
            if (_playerList != null)
            {
                _playerList.DeselectAll();
            }
            if (_selectBtn != null)
            {
                _selectBtn.Disabled = true;
            }
            if (_redStageBtn != null)
            {
                _redStageBtn.Disabled = true;
            }
            if (_blueStageBtn != null)
            {
                _blueStageBtn.Disabled = true;
            }
        }

        private void OnLoadCachePressed()
        {
            GD.Print("[PlayerSelector] OnLoadCachePressed() called - loading from user://data/players.json");
            if (_playerManager == null)
            {
                SetLoginStatus("No PlayerManager", false);
                GD.PrintErr("[PlayerSelector] PlayerManager is NULL, cannot load cache");
                return;
            }

            SetLoginStatus("Loading cache...", false);
            _playerManager.LoadFromLocal();
            SetLoginStatus($"Loaded {_playerManager.Players.Count} player(s) from cache ✓", true);
            UpdatePlayerList();
        }

        // 创建并定位右侧预览窗口（仅在首次调用时实例化，不重复创建）。
        private void EnsurePreviewPanel()
        {
            if (_previewPanel != null) return;
            try
            {
                var scene = GD.Load<PackedScene>("res://scene/stream/PlayerPreviewPanel.tscn");
                if (scene == null)
                {
                    GD.PrintErr("[PlayerSelector] PlayerPreviewPanel scene not found");
                    return;
                }
                _previewPanel = scene.Instantiate<PlayerPreviewPanel>();
                GetTree().Root.AddChild(_previewPanel);
                var ctrlWindow = FindControlPanel();
                if (ctrlWindow != null)
                    _previewPanel.PositionNextTo(ctrlWindow);
                _previewPanel.Visible = true;
                GD.Print("[PlayerSelector] Preview panel created and shown");
            }
            catch (System.Exception e)
            {
                GD.PrintErr($"[PlayerSelector] Failed to create preview panel: {e.Message}");
            }
        }

        // 用当前选中的选手刷新右侧预览（解说员模式清空预览）。
        private void UpdatePreview()
        {
            if (_previewPanel == null) return;
            if (!_isPlayerMode || _selectedPlayerId <= 0)
            {
                _previewPanel.Clear();
                return;
            }
            var dict = _playerManager?.GetPlayerDictionary(_selectedPlayerId);
            if (dict != null)
                _previewPanel.Display(dict);
        }

        private void UpdatePlayerList()
        {
            GD.Print($"[PlayerSelector] UpdatePlayerList called - PlayerList: {_playerList != null}, IsLoggedIn: {_isLoggedIn}");

            if (_playerList == null)
            {
                GD.PrintErr("[PlayerSelector] PlayerList is NULL!");
                return;
            }

            int previouslySelectedId = _selectedPlayerId;

            // If no player data at all, show empty list and friendly message
            bool hasPlayerData = _playerManager != null && _playerManager.Players.Count > 0;
            bool hasCommentatorData = _commentatorManager != null && _commentatorManager.Commentators.Count > 0;

            if (!hasPlayerData && !hasCommentatorData)
            {
                _playerList.Clear();
                _playerIdList.Clear();
                if (_playerList.GetParent() is VBoxContainer listContainer)
                {
                    var label = listContainer.GetNodeOrNull<Label>("PlayerListLabel");
                    if (label != null)
                        label.Text = "Players (login or load cache to see data)";
                }
                GD.Print("[PlayerSelector] No data available, list cleared");
                return;
            }

            _playerList.Clear();
            _playerIdList.Clear();

            if (_isPlayerMode)
            {
                var players = GetFilteredPlayers();
                GD.Print($"[PlayerSelector] Filtered players count: {players.Count}");
                if (_playerManager != null)
                {
                    GD.Print($"[PlayerSelector] Total players in manager: {_playerManager.Players.Count}");
                }
                foreach (var player in players)
                {
                    string displayName = $"{player.Nickname} ({player.Name})";
                    if (!string.IsNullOrEmpty(player.TeamName))
                    {
                        displayName += $" | {player.TeamName}";
                    }
                    // Mark staged players
                    if (player.Id == _stagedRedPlayerId)
                        displayName = "[R] " + displayName;
                    else if (player.Id == _stagedBluePlayerId)
                        displayName = "[B] " + displayName;

                    _playerList.AddItem(displayName);
                    _playerIdList.Add(player.Id);
                }
                UpdatePlayerListLabel($"Players ({players.Count})");
            }
            else
            {
                var commentators = GetFilteredCommentators();
                foreach (var commentator in commentators)
                {
                    string displayName = $"{commentator.Nickname} ({commentator.Name})";
                    if (!string.IsNullOrEmpty(commentator.Title))
                    {
                        displayName += $" | {commentator.Title}";
                    }
                    _playerList.AddItem(displayName);
                    _playerIdList.Add(commentator.Id);
                }
                UpdatePlayerListLabel($"Commentators ({commentators.Count})");
            }

            // Preserve the highlighted selection across rebuilds so a data
            // refresh doesn't silently drop the user's current selection.
            if (previouslySelectedId > 0 && _playerIdList.Contains(previouslySelectedId))
            {
                int idx = _playerIdList.IndexOf(previouslySelectedId);
                _selectedPlayerId = previouslySelectedId;
                _playerList.Select(idx);
                if (_selectBtn != null) _selectBtn.Disabled = false;
                if (_redStageBtn != null) _redStageBtn.Disabled = false;
                if (_blueStageBtn != null) _blueStageBtn.Disabled = false;
                UpdatePreview();
            }
            else if (_playerIdList.Count == 0)
            {
                ClearSelection();
            }
        }

        private void UpdatePlayerListLabel(string text)
        {
            if (_playerList == null) return;
            var listContainer = _playerList.GetParent() as VBoxContainer;
            if (listContainer == null) return;
            var label = listContainer.GetNodeOrNull<Label>("PlayerListLabel");
            if (label != null)
            {
                label.Text = text;
            }
        }

        private void UpdatePlayerDetail()
        {
            // 已废弃：左侧 Player Info 面板已移除，详情改在右侧 PlayerPreviewPanel 显示。
            // 保留空方法以避免改动调用方（OnPlayerListItemSelected 中不再调用此方法）。
        }

        private void LoadPlayerAvatar(PlayerData player)
        {
            // 已废弃：头像加载已统一由 PlayerAvatarDisplay / StreamPlayerCard 自己处理。
        }

        private List<PlayerData> GetFilteredPlayers()
        {
            if (_playerManager == null) return new List<PlayerData>();
            string keyword = _searchInput?.Text ?? "";
            return _playerManager.SearchPlayers(keyword);
        }

        private List<CommentatorData> GetFilteredCommentators()
        {
            if (_commentatorManager == null) return new List<CommentatorData>();
            string keyword = _searchInput?.Text ?? "";
            return _commentatorManager.SearchCommentators(keyword);
        }

        private void OnPlayersLoadedFromApi(Godot.Collections.Dictionary data)
        {
            GD.Print("[PlayerSelector] Players loaded from API");
            GD.Print("[PlayerSelector] Data keys: ", string.Join(", ", data.Keys));

            if (_playerManager != null)
            {
                GD.Print("[PlayerSelector] Loading players into PlayerManager...");
                _playerManager.LoadPlayers(data);
                GD.Print("[PlayerSelector] Players in manager after load: ", _playerManager.Players.Count);
            }
            else
            {
                GD.PrintErr("[PlayerSelector] PlayerManager is NULL in OnPlayersLoadedFromApi!");
            }

            SetLoggedIn(true);
            int synced = _playerManager != null ? _playerManager.Players.Count : 0;
            SetLoginStatus($"Sync OK — synced {synced} player(s) ✓", true);
            GD.Print("[PlayerSelector] SetLoggedIn(true) called");
            UpdatePlayerList();
            GD.Print("[PlayerSelector] UpdatePlayerList() called");
        }

        private void OnPlayersUpdated()
        {
            GD.Print("[PlayerSelector] Players updated");
            UpdatePlayerList();
            // Refresh stage display after player data reload
            RefreshStageDisplays();
        }

        private void OnCommentatorsUpdated()
        {
            if (!_isPlayerMode)
            {
                UpdatePlayerList();
            }
        }

        // 玩家数据重新加载后，把已上台的选手重新 emit 给 main.gd 统一刷新显示。
        private void RefreshStageDisplays()
        {
            var window = FindControlPanel();
            if (window == null || !window.HasSignal("stage_player")) return;

            if (_stagedRedPlayerId > 0)
                window.EmitSignal("stage_player", _stagedRedPlayerId, "Red");
            if (_stagedBluePlayerId > 0)
                window.EmitSignal("stage_player", _stagedBluePlayerId, "Blue");
        }
    }
}
