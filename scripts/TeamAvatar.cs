using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 队伍头像控件：以 TextureRect 自身显示当前上台选手所属队伍的队徽（team_logo）。
    ///
    /// 数据来源与 PlayerImageField 一致：main.gd 会把「上台选手字典」传给所有实现了
    /// DisplayPlayer(dict) 的节点；节点名称含 "red"/"blue" 时按红蓝方分流，否则按当前
    /// 主题显示对应一方。队徽按 URL 缓存，GIF 自动取首帧。
    /// </summary>
    public partial class TeamAvatar : TextureRect
    {
        public enum ImageKind { TeamLogo, TeamPhoto, Avatar }

        [Export] public string BaseUrl = "https://lskb.cc.cd";
        [Export] public string AvatarLoaderPath = "/root/Main/AvatarLoader";
        [Export] public ImageKind Kind = ImageKind.TeamLogo;
        [Export] public bool UseTeamLogoAsFallback = true;   // 仅 Avatar 模式：头像缺失时回退队徽

        private AvatarLoader _avatarLoader;
        private int _currentId = -1;
        private string _currentUrl = "";

        public override void _Ready()
        {
            EnsureAvatarLoader();
            Clear();
        }

        private void EnsureAvatarLoader()
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

        private static string KeyFor(ImageKind kind) =>
            kind switch
            {
                ImageKind.TeamLogo => "team_logo",
                ImageKind.TeamPhoto => "team_photo",
                ImageKind.Avatar => "avatar",
                _ => ""
            };

        private static string Get(Godot.Collections.Dictionary player, string key)
        {
            if (player == null || !player.ContainsKey(key)) return "";
            Variant v = player[key];
            return v.VariantType == Variant.Type.Nil ? "" : v.ToString();
        }

        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                Clear();
                return;
            }

            int id = (int)player["id"];
            _currentId = id;

            string primary = Get(player, KeyFor(Kind));
            string fallback = (Kind == ImageKind.Avatar && UseTeamLogoAsFallback) ? Get(player, "team_logo") : "";

            string url = ToAbsoluteUrl(primary);
            if (string.IsNullOrEmpty(url) && !string.IsNullOrEmpty(fallback))
                url = ToAbsoluteUrl(fallback);

            Texture = null;
            Visible = false;

            if (string.IsNullOrEmpty(url))
            {
                // 无 URL 时尝试用本地缓存兜底
                var local = _avatarLoader.GetLocalAvatar(id);
                if (local != null)
                {
                    Texture = local;
                    Visible = true;
                }
                return;
            }

            _currentUrl = url;

            if (Kind == ImageKind.Avatar)
            {
                _avatarLoader.LoadAvatar(id, url,
                    (loadedId, tex) =>
                    {
                        if (loadedId != _currentId || this == null) return;
                        Texture = tex;
                        Visible = true;
                    },
                    (loadedId, err) =>
                    {
                        if (loadedId != _currentId) return;
                        var local = _avatarLoader.GetLocalAvatar(id);
                        if (local != null && this != null)
                        {
                            Texture = local;
                            Visible = true;
                        }
                    });
            }
            else
            {
                _avatarLoader.LoadImage(url,
                    tex =>
                    {
                        if (_currentUrl != url || this == null) return;
                        Texture = tex;
                        Visible = true;
                    },
                    err => { });
            }
        }

        private string ToAbsoluteUrl(string url)
        {
            if (string.IsNullOrEmpty(url)) return "";
            if (url.StartsWith("http://") || url.StartsWith("https://")) return url;
            if (url.StartsWith("//")) return "https:" + url;
            if (url.StartsWith("/")) return BaseUrl.TrimEnd('/') + url;
            return BaseUrl.TrimEnd('/') + "/" + url;
        }

        public void Clear()
        {
            _currentId = -1;
            _currentUrl = "";
            Texture = null;
            Visible = false;
        }
    }
}
