using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 零散文本控件：只显示选手/队伍字典中的「某一个字段」。
    /// 以 Node2D 为根（与 player_avatar.tscn 同级），可自由拖入任意 2D 场景并摆放位置，
    /// 每个实例独立配置要显示哪个字段，互不干扰。
    ///
    /// 数据来源：main.gd 会自动把上台选手的字典传给所有实现了 DisplayPlayer(dict) 的节点
    /// （通过 _collect_display_nodes 扫描）。节点名称含 "red"/"blue" 即按红蓝方分流，
    /// 否则按当前主题(current_mode)显示对应一方。
    /// </summary>
    public partial class PlayerFieldLabel : Node2D
    {
        public enum FieldKey
        {
            Custom,       // 用下方 CustomField 自定义键名
            Id,
            Username,     // 用户名
            Nickname,     // 昵称
            School,       // 学校（squad 别名）
            Squad,        // 分队
            TeamId,       // 队伍 ID
            TeamName,     // 队伍名
            Rating,       // 评分
            Wins,         // 胜
            Losses,       // 负
            Draws,        // 平
            WinRate,      // 胜率（自动计算）
            Role,         // 角色（captain 显示为「队长」）
            CreatedAt,    // 创建时间
            Operator,     // 运营
            Roguelike,    // 肉鸽模式
            TeamPhoto,    // 队伍照片 URL
            FinalScore,   // 最终分
            Declaration,  // 宣言
            Opening       // 开局词
        }

        [Export] public FieldKey Field = FieldKey.Username;
        [Export] public string CustomField = "";     // Field == Custom 时使用，可显示任意原始键（含 team_xxx）
        [Export] public string StaticLabel = "";     // 固定前缀，如 "选手名："（始终显示，不随数据变化）
        [Export] public string Prefix = "";          // 值前缀
        [Export] public string Suffix = "";          // 值后缀
        [Export] public string Fallback = "-";       // 数据缺失时显示
        [Export] public bool AutoColor = false;       // 跟随红/蓝主题着色

        private Label _label;

        public override void _Ready()
        {
            _label = FindChild("Label", true, false) as Label;
            Clear();
        }

        private static string KeyFor(FieldKey f)
        {
            switch (f)
            {
                case FieldKey.Id: return "id";
                case FieldKey.Username: return "username";
                case FieldKey.Nickname: return "nickname";
                case FieldKey.School: return "school";
                case FieldKey.Squad: return "squad";
                case FieldKey.TeamId: return "team_id";
                case FieldKey.TeamName: return "team_name";
                case FieldKey.Rating: return "rating";
                case FieldKey.Wins: return "wins";
                case FieldKey.Losses: return "losses";
                case FieldKey.Draws: return "draws";
                case FieldKey.WinRate: return "__winrate__";
                case FieldKey.Role: return "role";
                case FieldKey.CreatedAt: return "created_at";
                case FieldKey.Operator: return "operator";
                case FieldKey.Roguelike: return "roguelike";
                case FieldKey.TeamPhoto: return "team_photo";
                case FieldKey.FinalScore: return "final_score";
                case FieldKey.Declaration: return "declaration";
                case FieldKey.Opening: return "opening";
                default: return "";
            }
        }

        private string ResolveValue(Godot.Collections.Dictionary player, string key)
        {
            if (key == "__winrate__")
            {
                int w = player.ContainsKey("wins") ? (int)player["wins"] : 0;
                int l = player.ContainsKey("losses") ? (int)player["losses"] : 0;
                int d = player.ContainsKey("draws") ? (int)player["draws"] : 0;
                int total = w + l + d;
                double rate = total == 0 ? 0 : (double)(w + d * 0.5) / total * 100;
                return $"{rate:F1}%";
            }
            if (string.IsNullOrEmpty(key)) return "";
            if (!player.ContainsKey(key)) return "";
            Variant v = player[key];
            if (v.VariantType == Variant.Type.Nil) return "";
            string s = v.ToString();
            if (key == "role" && s == "captain") return "队长";
            return s;
        }

        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (_label == null) return;
            if (player == null || !player.ContainsKey("id"))
            {
                Clear();
                return;
            }
            string key = Field == FieldKey.Custom ? CustomField : KeyFor(Field);
            string value = ResolveValue(player, key);
            string shown = string.IsNullOrEmpty(value) ? Fallback : Prefix + value + Suffix;
            _label.Text = (string.IsNullOrEmpty(StaticLabel) ? "" : StaticLabel) + shown;
        }

        public void Clear()
        {
            if (_label != null)
                _label.Text = (string.IsNullOrEmpty(StaticLabel) ? "" : StaticLabel) + Fallback;
        }

        // 由 main.gd 在主题切换时调用，使标签跟随红/蓝配色
        public void UpdateWithMode(string mode)
        {
            if (_label == null || !AutoColor) return;
            Color c = mode == "Red" ? new Color(1f, 0.3f, 0.3f) : new Color(0.223f, 0.571f, 0.771f);
            _label.AddThemeColorOverride("font_color", c);
        }
    }
}
