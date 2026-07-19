using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 独立浮动预览窗口，显示在控制面板右侧，实时展示当前选中选手的卡片。
    /// 完全独立于控制面板内的按钮布局，不影响任何现有 UI。
    /// </summary>
    public partial class PlayerPreviewPanel : Window
    {
        private StreamPlayerCard _card;

        public override void _Ready()
        {
            _card = ResolveCard();

            if (_card == null)
            {
                GD.PrintErr("[PlayerPreviewPanel] StreamPlayerCard child NOT found. Children tree:" + DumpChildren(this));
            }
            else
            {
                // 安全网：无论 tscn 怎么写，强制让卡片填满窗口（留 8px 内边距），
                // 解决 Window 的直接子 Control 在 SubViewport 里的 anchor/offset 解析问题。
                _card.AnchorLeft = 0f;
                _card.AnchorTop = 0f;
                _card.AnchorRight = 1f;
                _card.AnchorBottom = 1f;
                _card.OffsetLeft = 8f;
                _card.OffsetTop = 8f;
                _card.OffsetRight = -8f;
                _card.OffsetBottom = -8f;
                GD.Print($"[PlayerPreviewPanel] _card resolved, rect={_card.Position},{_card.Size}");
            }

            Clear();
        }

        // 稳健定位 StreamPlayerCard：先按名字取 Node 再 as 转换（规避实例根节点的泛型歧义），
        // 失败则递归遍历整棵子树。
        private StreamPlayerCard ResolveCard()
        {
            var node = GetNodeOrNull("StreamPlayerCard");
            if (node is StreamPlayerCard direct) return direct;
            return FindCardRecursive(this);
        }

        private StreamPlayerCard FindCardRecursive(Node node)
        {
            if (node is StreamPlayerCard c) return c;
            foreach (var child in node.GetChildren())
            {
                var found = FindCardRecursive(child);
                if (found != null) return found;
            }
            return null;
        }

        private static string DumpChildren(Node node, int depth = 0)
        {
            var sb = new System.Text.StringBuilder();
            foreach (var child in node.GetChildren())
            {
                sb.Append($"\n{new string(' ', depth * 2)}- {child.Name} ({child.GetType().Name})");
                sb.Append(DumpChildren(child, depth + 1));
            }
            return sb.ToString();
        }

        public void Display(Godot.Collections.Dictionary player)
        {
            if (_card != null)
            {
                _card.Display(player);
                GD.Print($"[PlayerPreviewPanel] Display -> card rect={_card.Position},{_card.Size}");
            }
            else
            {
                GD.PrintErr("[PlayerPreviewPanel] Display called but _card is null");
            }
            Visible = true;
        }

        public void Clear()
        {
            if (_card != null)
                _card.Clear();
        }

        // 把本窗口贴在 anchor 窗口的右侧（间隔 8px）。
        public void PositionNextTo(Window anchor)
        {
            if (anchor == null) return;
            Position = new Vector2I(anchor.Position.X + anchor.Size.X + 8, anchor.Position.Y);
        }
    }
}
