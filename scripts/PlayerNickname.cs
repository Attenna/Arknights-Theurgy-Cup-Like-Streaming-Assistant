using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 选手昵称标签：挂在 Label 上，由 main.gd 调用 DisplayPlayer(dict)
    /// 显示当前上台选手的 nickname。只负责改文字，不做着色。
    ///
    /// 注意：Godot 的 C# 脚本要求类名与文件名一致（本文件必须为 PlayerNickname.cs）。
    /// </summary>
    public partial class PlayerNickname : Label
    {
        public override void _Ready()
        {
            ClearNickname();
        }

        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                ClearNickname();
                return;
            }

            string nick = "";
            if (player.ContainsKey("nickname") && player["nickname"].VariantType != Variant.Type.Nil)
                nick = player["nickname"].ToString();

            Text = nick;
        }

        public void ClearNickname()
        {
            Text = "";
        }
    }
}
