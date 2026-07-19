using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 干员头像显示组件（继承自 TextureRect）。
    /// 给定一个干员名称，自动从 PRTS Wiki 抓取并显示其头像。
    /// 通过场景树中的 AvatarLoader 节点完成实际的图片下载与缓存。
    /// </summary>
    public partial class OperatorAvatar : TextureRect
    {
        /// <summary>
        /// 场景树中 AvatarLoader 节点的路径（用于实际图片下载）。
        /// 留空则从整棵场景树自动查找第一个 AvatarLoader。
        /// </summary>
        [Export] public NodePath AvatarLoaderPath = new();

        private AvatarLoader _avatarLoader;
        private string _currentOperator = "";

        public override void _Ready()
        {
            EnsureAvatarLoader();
            ClearOperator();
        }

        /// <summary>
        /// 由 main.gd 统一调用（DisplayPlayer 协议）。
        /// 从选手字典读取 operator 字段并加载干员头像。
        /// </summary>
        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                ClearOperator();
                return;
            }

            string op = "";
            if (player.ContainsKey("operator") && player["operator"].VariantType != Variant.Type.Nil)
                op = player["operator"].ToString();

            SetOperator(op);
        }

        private void EnsureAvatarLoader()
        {
            if (!string.IsNullOrEmpty(AvatarLoaderPath?.ToString()))
            {
                _avatarLoader = GetNodeOrNull<AvatarLoader>(AvatarLoaderPath);
            }
            if (_avatarLoader == null)
            {
                // 自动在整棵场景树中查找已有的 AvatarLoader，避免创建重复实例。
                _avatarLoader = GetTree().Root.FindChild("AvatarLoader", true, false) as AvatarLoader;
            }
            if (_avatarLoader == null)
            {
                _avatarLoader = new AvatarLoader();
                GetTree().Root.AddChild(_avatarLoader);
            }
        }

        /// <summary>
        /// 设置要显示的干员名称并异步加载头像。
        /// 传入空字符串或 null 则清空显示。
        /// </summary>
        /// <param name="operatorName">干员中文名（来自选手数据 operator 字段）</param>
        public void SetOperator(string operatorName)
        {
            Texture = null;
            Visible = false;
            _currentOperator = "";

            if (string.IsNullOrEmpty(operatorName))
                return;

            // 兜底：若 _Ready 尚未执行或 AvatarLoader 丢失，则在此补建。
            if (_avatarLoader == null)
                EnsureAvatarLoader();

            if (_avatarLoader == null)
                return;

            string url = OperatorAvatarLoader.GetAvatarUrl(operatorName);
            if (string.IsNullOrEmpty(url))
                return;

            _currentOperator = operatorName;

            _avatarLoader.LoadImage(url,
                tex =>
                {
                    // 加载期间若已切换到其他干员，丢弃过期结果。
                    if (_currentOperator == operatorName)
                    {
                        Texture = tex;
                        Visible = true;
                    }
                },
                err =>
                {
                    GD.PrintErr($"[OperatorAvatar] 加载干员头像失败 [{operatorName}]: {err}");
                });
        }

        /// <summary>
        /// 清空头像显示。
        /// </summary>
        public void ClearOperator()
        {
            Texture = null;
            Visible = false;
            _currentOperator = "";
        }
    }
}
