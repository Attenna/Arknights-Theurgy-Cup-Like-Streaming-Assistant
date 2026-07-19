using Godot;

namespace PlayerStatistics
{
    public partial class PlayerInfoDisplay : Control
    {
        [Export] public string NameLabelPath = "NameLabel";
        [Export] public string NicknameLabelPath = "NicknameLabel";
        [Export] public string SchoolLabelPath = "SchoolLabel";
        [Export] public string TeamLabelPath = "TeamLabel";
        [Export] public string RatingLabelPath = "RatingLabel";
        [Export] public string WinsLabelPath = "WinsLabel";
        [Export] public string LossesLabelPath = "LossesLabel";
        [Export] public string DrawsLabelPath = "DrawsLabel";
        [Export] public string WinRateLabelPath = "WinRateLabel";

        // 新增：队伍信息 / 附加信息标签路径
        [Export] public string RoleLabelPath = "RoleLabel";
        [Export] public string OperatorLabelPath = "OperatorLabel";
        [Export] public string RoguelikeLabelPath = "RoguelikeLabel";
        [Export] public string SquadLabelPath = "SquadLabel";
        [Export] public string FinalScoreLabelPath = "FinalScoreLabel";
        [Export] public string DeclarationLabelPath = "DeclarationLabel";
        [Export] public string OpeningLabelPath = "OpeningLabel";

        [Export] public string OperatorAvatarRectPath = "OperatorAvatarRect";

        private Label _nameLabel;
        private Label _nicknameLabel;
        private Label _schoolLabel;
        private Label _teamLabel;
        private Label _ratingLabel;
        private Label _winsLabel;
        private Label _lossesLabel;
        private Label _drawsLabel;
        private Label _winRateLabel;
        private Label _roleLabel;
        private Label _operatorLabel;
        private Label _roguelikeLabel;
        private Label _squadLabel;
        private Label _finalScoreLabel;
        private Label _declarationLabel;
        private Label _openingLabel;

        private OperatorAvatar _operatorAvatarRect;

        public override void _Ready()
        {
            _nameLabel = GetNodeOrNull<Label>(NameLabelPath);
            _nicknameLabel = GetNodeOrNull<Label>(NicknameLabelPath);
            _schoolLabel = GetNodeOrNull<Label>(SchoolLabelPath);
            _teamLabel = GetNodeOrNull<Label>(TeamLabelPath);
            _ratingLabel = GetNodeOrNull<Label>(RatingLabelPath);
            _winsLabel = GetNodeOrNull<Label>(WinsLabelPath);
            _lossesLabel = GetNodeOrNull<Label>(LossesLabelPath);
            _drawsLabel = GetNodeOrNull<Label>(DrawsLabelPath);
            _winRateLabel = GetNodeOrNull<Label>(WinRateLabelPath);
            _roleLabel = GetNodeOrNull<Label>(RoleLabelPath);
            _operatorLabel = GetNodeOrNull<Label>(OperatorLabelPath);
            _roguelikeLabel = GetNodeOrNull<Label>(RoguelikeLabelPath);
            _squadLabel = GetNodeOrNull<Label>(SquadLabelPath);
            _finalScoreLabel = GetNodeOrNull<Label>(FinalScoreLabelPath);
            _declarationLabel = GetNodeOrNull<Label>(DeclarationLabelPath);
            _openingLabel = GetNodeOrNull<Label>(OpeningLabelPath);

            _operatorAvatarRect = GetNodeOrNull<OperatorAvatar>(OperatorAvatarRectPath);

            Clear();
        }

        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                Clear();
                return;
            }

            string Get(string key, string fallback) =>
                player.ContainsKey(key) ? player[key].ToString() : fallback;

            if (_nameLabel != null)
                _nameLabel.Text = Get("username", "-");

            if (_nicknameLabel != null)
                _nicknameLabel.Text = string.IsNullOrEmpty(Get("nickname", "")) ? "-" : Get("nickname", "");

            if (_schoolLabel != null)
                _schoolLabel.Text = string.IsNullOrEmpty(Get("school", "")) ? "-" : Get("school", "");

            if (_teamLabel != null)
                _teamLabel.Text = string.IsNullOrEmpty(Get("team_name", "")) ? "-" : Get("team_name", "");

            if (_ratingLabel != null)
                _ratingLabel.Text = player.ContainsKey("rating") ? player["rating"].ToString() : "-";

            if (_winsLabel != null)
                _winsLabel.Text = player.ContainsKey("wins") ? player["wins"].ToString() : "-";

            if (_lossesLabel != null)
                _lossesLabel.Text = player.ContainsKey("losses") ? player["losses"].ToString() : "-";

            if (_drawsLabel != null)
                _drawsLabel.Text = player.ContainsKey("draws") ? player["draws"].ToString() : "-";

            if (_winRateLabel != null)
            {
                int w = player.ContainsKey("wins") ? (int)player["wins"] : 0;
                int l = player.ContainsKey("losses") ? (int)player["losses"] : 0;
                int d = player.ContainsKey("draws") ? (int)player["draws"] : 0;
                int total = w + l + d;
                double rate = total == 0 ? 0 : (double)(w + d * 0.5) / total * 100;
                _winRateLabel.Text = $"{rate:F1}%";
            }

            if (_roleLabel != null)
            {
                string role = Get("role", "");
                _roleLabel.Text = string.IsNullOrEmpty(role) ? "-" : (role == "captain" ? "队长" : role);
            }
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

            GD.Print($"[PlayerInfoDisplay] Displaying player: {Get("username", "")}");

            string operatorName = Get("operator", "");
            _operatorAvatarRect?.SetOperator(operatorName);
        }

        public void Clear()
        {
            if (_nameLabel != null)
                _nameLabel.Text = "-";

            if (_nicknameLabel != null)
                _nicknameLabel.Text = "-";

            if (_schoolLabel != null)
                _schoolLabel.Text = "-";

            if (_teamLabel != null)
                _teamLabel.Text = "-";

            if (_ratingLabel != null)
                _ratingLabel.Text = "-";

            if (_winsLabel != null)
                _winsLabel.Text = "-";

            if (_lossesLabel != null)
                _lossesLabel.Text = "-";

            if (_drawsLabel != null)
                _drawsLabel.Text = "-";

            if (_winRateLabel != null)
                _winRateLabel.Text = "-";
            if (_roleLabel != null)
                _roleLabel.Text = "-";
            if (_operatorLabel != null)
                _operatorLabel.Text = "-";
            if (_roguelikeLabel != null)
                _roguelikeLabel.Text = "-";
            if (_squadLabel != null)
                _squadLabel.Text = "-";
            if (_finalScoreLabel != null)
                _finalScoreLabel.Text = "-";
            if (_declarationLabel != null)
                _declarationLabel.Text = "-";
            if (_openingLabel != null)
                _openingLabel.Text = "-";
            _operatorAvatarRect?.ClearOperator();
        }

        public void UpdateWithMode(string mode)
        {
            Color accentColor = mode == "Red" ? new Color(1, 0.3f, 0.3f) : new Color(0.223f, 0.571f, 0.771f);

            UpdateLabelColor(_nameLabel, accentColor);
            UpdateLabelColor(_ratingLabel, accentColor);
            UpdateLabelColor(_winRateLabel, accentColor);
        }

        private void UpdateLabelColor(Label label, Color color)
        {
            if (label != null)
            {
                label.AddThemeColorOverride("font_color", color);
            }
        }
    }
}
