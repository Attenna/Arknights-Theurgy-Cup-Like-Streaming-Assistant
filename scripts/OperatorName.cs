using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 干员名称显示组件（继承自 Label）。
    /// 由 main.gd 统一调用 DisplayPlayer()，显示选手的「开局干员」字段。
    /// </summary>
    public partial class OperatorName : Label
    {
        public override void _Ready()
        {
            Text = "-";
        }

        /// <summary>
        /// 由 main.gd 统一调用（DisplayPlayer 协议）。
        /// 从选手字典读取 operator 字段并显示。
        /// </summary>
        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                Text = "-";
                return;
            }

            string op = "";
            if (player.ContainsKey("operator") && player["operator"].VariantType != Variant.Type.Nil)
                op = player["operator"].ToString();

            Text = string.IsNullOrEmpty(op) ? "-" : $"开局干员：{op}";
        }
    }
}
