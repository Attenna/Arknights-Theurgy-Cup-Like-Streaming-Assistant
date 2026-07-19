using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 可继承的直播选手信息卡片。直接继承此场景（或此类）即可复用头像下载与信息显示逻辑。
    /// 显示的数据来自一个 Godot.Collections.Dictionary（与 PlayerManager.GetPlayerDictionary 输出一致）。
    /// </summary>
    public partial class StreamPlayerCard : Control
    {
        [Export] public string BaseUrl = "https://lskb.cc.cd";
        [Export] public string AvatarLoaderPath = "/root/Main/AvatarLoader";
        [Export] public bool UseTeamLogoAsFallback = true;

        // 节点名（用 FindChild 递归查找，因此布局可自由嵌套）
        protected TextureRect _avatarRect;
        protected TextureRect _teamLogoRect;
        protected Label _nameLabel;
        protected Label _nicknameLabel;
        protected Label _teamLabel;
        protected Label _ratingLabel;
        protected Label _recordLabel;
        protected Label _winRateLabel;

        // 新增：队伍信息 / 附加信息标签（节点缺失时自动跳过，向后兼容）
        protected Label _roleLabel;
        protected Label _operatorLabel;
        protected Label _roguelikeLabel;
        protected Label _squadLabel;
        protected Label _finalScoreLabel;
        protected Label _declarationLabel;
        protected Label _openingLabel;

        protected OperatorAvatar _operatorAvatarRect;

        protected AvatarLoader _avatarLoader;

        public override void _Ready()
        {
            CacheNodes();
            EnsureAvatarLoader();
            Clear();
        }

        protected void CacheNodes()
        {
            _avatarRect = FindChild("AvatarRect", true, false) as TextureRect;
            _teamLogoRect = FindChild("TeamLogoRect", true, false) as TextureRect;
            _nameLabel = FindChild("NameLabel", true, false) as Label;
            _nicknameLabel = FindChild("NicknameLabel", true, false) as Label;
            _teamLabel = FindChild("TeamLabel", true, false) as Label;
            _ratingLabel = FindChild("RatingLabel", true, false) as Label;
            _recordLabel = FindChild("RecordLabel", true, false) as Label;
            _winRateLabel = FindChild("WinRateLabel", true, false) as Label;
            _roleLabel = FindChild("RoleLabel", true, false) as Label;
            _operatorLabel = FindChild("OperatorLabel", true, false) as Label;
            _roguelikeLabel = FindChild("RoguelikeLabel", true, false) as Label;
            _squadLabel = FindChild("SquadLabel", true, false) as Label;
            _finalScoreLabel = FindChild("FinalScoreLabel", true, false) as Label;
            _declarationLabel = FindChild("DeclarationLabel", true, false) as Label;
            _openingLabel = FindChild("OpeningLabel", true, false) as Label;
            _operatorAvatarRect = FindChild("OperatorAvatarRect", true, false) as OperatorAvatar;
        }

        protected void EnsureAvatarLoader()
        {
            _avatarLoader = GetNodeOrNull<AvatarLoader>(AvatarLoaderPath);
            if (_avatarLoader == null)
                _avatarLoader = GetTree().Root.GetNodeOrNull<AvatarLoader>("Main/AvatarLoader");
            if (_avatarLoader == null)
            {
                _avatarLoader = new AvatarLoader();
                AddChild(_avatarLoader);
            }
        }

        /// <summary>
        /// 显示一名选手。player 需包含 id / username / nickname / team_name / rating / wins / losses / draws / avatar / team_logo。
        /// </summary>
        public virtual void Display(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                Clear();
                return;
            }

            int id = (int)player["id"];
            string Get(string key, string fallback) =>
                player.ContainsKey(key) ? player[key].ToString() : fallback;

            if (_nameLabel != null) _nameLabel.Text = Get("username", "-");
            if (_nicknameLabel != null)
                _nicknameLabel.Text = string.IsNullOrEmpty(Get("nickname", "")) ? "-" : Get("nickname", "");
            if (_teamLabel != null)
                _teamLabel.Text = string.IsNullOrEmpty(Get("team_name", "")) ? "-" : Get("team_name", "");
            if (_ratingLabel != null)
                _ratingLabel.Text = player.ContainsKey("rating") ? player["rating"].ToString() : "-";

            int w = player.ContainsKey("wins") ? (int)player["wins"] : 0;
            int l = player.ContainsKey("losses") ? (int)player["losses"] : 0;
            int d = player.ContainsKey("draws") ? (int)player["draws"] : 0;
            if (_recordLabel != null) _recordLabel.Text = $"{w} - {l} - {d}";
            if (_winRateLabel != null)
            {
                int total = w + l + d;
                double rate = total == 0 ? 0 : (double)(w + d * 0.5) / total * 100;
                _winRateLabel.Text = $"{rate:F1}%";
            }

            string role = Get("role", "");
            if (_roleLabel != null) _roleLabel.Text = string.IsNullOrEmpty(role) ? "-" : (role == "captain" ? "队长" : role);
            if (_operatorLabel != null)
            {
                string op = Get("operator", "");
                _operatorLabel.Text = string.IsNullOrEmpty(op) ? "-" : $"开局干员：{op}";
            }
            if (_roguelikeLabel != null)
            {
                string rl = Get("roguelike", "");
                _roguelikeLabel.Text = string.IsNullOrEmpty(rl) ? "-" : $"肉鸽：{rl}";
            }
            if (_squadLabel != null)
            {
                string sq = Get("squad", "");
                _squadLabel.Text = string.IsNullOrEmpty(sq) ? "-" : $"分队：{sq}";
            }
            if (_finalScoreLabel != null)
            {
                string fs = Get("final_score", "");
                _finalScoreLabel.Text = string.IsNullOrEmpty(fs) ? "-" : $"最终分：{fs}";
            }
            if (_declarationLabel != null)
            {
                string dec = Get("declaration", "");
                _declarationLabel.Text = string.IsNullOrEmpty(dec) ? "-" : $"宣言：{dec}";
            }
            if (_openingLabel != null)
            {
                string opn = Get("opening", "");
                _openingLabel.Text = string.IsNullOrEmpty(opn) ? "-" : $"开局：{opn}";
            }

            LoadImages(id, Get("avatar", ""), Get("team_logo", ""));
            _operatorAvatarRect?.SetOperator(Get("operator", ""));
        }

        /// <summary>
        /// 用红/蓝主题色高亮卡片（直播对阵常用）。
        /// </summary>
        public virtual void DisplayWithMode(string mode)
        {
            Color accent = mode == "Red"
                ? new Color(1, 0.3f, 0.3f)
                : new Color(0.223f, 0.571f, 0.771f);
            ApplyAccent(accent);
        }

        protected virtual void ApplyAccent(Color color)
        {
            ApplyColor(_nameLabel, color);
            ApplyColor(_ratingLabel, color);
            ApplyColor(_winRateLabel, color);
        }

        protected void ApplyColor(Label label, Color color)
        {
            if (label != null)
                label.AddThemeColorOverride("font_color", color);
        }

        protected void LoadImages(int id, string playerAvatar, string teamLogo)
        {
            if (_avatarLoader == null) return;

            string playerUrl = ToAbsoluteUrl(playerAvatar);
            string teamUrl = ToAbsoluteUrl(teamLogo);
            bool usingTeamFallback = false;

            if (string.IsNullOrEmpty(playerUrl) && UseTeamLogoAsFallback && !string.IsNullOrEmpty(teamUrl))
            {
                playerUrl = teamUrl;
                usingTeamFallback = true;
            }

            if (_avatarRect != null) { _avatarRect.Texture = null; _avatarRect.Visible = false; }
            if (_teamLogoRect != null) { _teamLogoRect.Texture = null; _teamLogoRect.Visible = false; }

            if (!string.IsNullOrEmpty(playerUrl))
            {
                _avatarLoader.LoadAvatar(id, playerUrl,
                    (loadedId, tex) =>
                    {
                        if (loadedId != id || _avatarRect == null) return;
                        _avatarRect.Texture = tex;
                        _avatarRect.Visible = true;
                    },
                    (loadedId, err) =>
                    {
                        if (loadedId != id) return;
                        var local = _avatarLoader.GetLocalAvatar(id);
                        if (local != null && _avatarRect != null)
                        {
                            _avatarRect.Texture = local;
                            _avatarRect.Visible = true;
                        }
                    });
            }
            else
            {
                var local = _avatarLoader.GetLocalAvatar(id);
                if (local != null && _avatarRect != null)
                {
                    _avatarRect.Texture = local;
                    _avatarRect.Visible = true;
                }
            }

            if (!string.IsNullOrEmpty(teamUrl) && _teamLogoRect != null && !usingTeamFallback)
            {
                _avatarLoader.LoadImage(teamUrl,
                    tex =>
                    {
                        if (_teamLogoRect != null) { _teamLogoRect.Texture = tex; _teamLogoRect.Visible = true; }
                    },
                    err => { });
            }
        }

        protected string ToAbsoluteUrl(string url)
        {
            if (string.IsNullOrEmpty(url)) return "";
            if (url.StartsWith("http://") || url.StartsWith("https://")) return url;
            if (url.StartsWith("//")) return "https:" + url;
            if (url.StartsWith("/")) return BaseUrl.TrimEnd('/') + url;
            return BaseUrl.TrimEnd('/') + "/" + url;
        }

        public virtual void Clear()
        {
            if (_nameLabel != null) _nameLabel.Text = "-";
            if (_nicknameLabel != null) _nicknameLabel.Text = "-";
            if (_teamLabel != null) _teamLabel.Text = "-";
            if (_ratingLabel != null) _ratingLabel.Text = "-";
            if (_recordLabel != null) _recordLabel.Text = "-";
            if (_winRateLabel != null) _winRateLabel.Text = "-";
            if (_roleLabel != null) _roleLabel.Text = "-";
            if (_operatorLabel != null) _operatorLabel.Text = "-";
            if (_roguelikeLabel != null) _roguelikeLabel.Text = "-";
            if (_squadLabel != null) _squadLabel.Text = "-";
            if (_finalScoreLabel != null) _finalScoreLabel.Text = "-";
            if (_declarationLabel != null) _declarationLabel.Text = "-";
            if (_openingLabel != null) _openingLabel.Text = "-";
            if (_avatarRect != null) { _avatarRect.Texture = null; _avatarRect.Visible = false; }
            if (_teamLogoRect != null) { _teamLogoRect.Texture = null; _teamLogoRect.Visible = false; }
            _operatorAvatarRect?.ClearOperator();
        }
    }
}
