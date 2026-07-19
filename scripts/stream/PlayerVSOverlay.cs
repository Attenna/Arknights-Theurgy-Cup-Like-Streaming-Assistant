using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 直播对阵场景：左右两张 StreamPlayerCard（红方/蓝方）。
    /// 继承此场景后，可在编辑器中调整布局与配色。
    /// </summary>
    public partial class PlayerVSOverlay : Control
    {
        [Export] public NodePath RedCardPath = "RedCard";
        [Export] public NodePath BlueCardPath = "BlueCard";

        private StreamPlayerCard _redCard;
        private StreamPlayerCard _blueCard;

        public override void _Ready()
        {
            _redCard = GetNodeOrNull<StreamPlayerCard>(RedCardPath);
            _blueCard = GetNodeOrNull<StreamPlayerCard>(BlueCardPath);

            _redCard?.DisplayWithMode("Red");
            _blueCard?.DisplayWithMode("Blue");
        }

        public void DisplayRed(Godot.Collections.Dictionary player)
        {
            _redCard?.Display(player);
        }

        public void DisplayBlue(Godot.Collections.Dictionary player)
        {
            _blueCard?.Display(player);
        }

        public void ClearAll()
        {
            _redCard?.Clear();
            _blueCard?.Clear();
        }
    }
}
