using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 零散图片控件：显示选手头像 / 队徽 / 队伍照片中的「一张图」。
    /// 以 Node2D 为根（与 player_avatar.tscn 类似），可在 2D 场景内自由摆放位置。
    ///
    /// 数据来源同 PlayerFieldLabel：main.gd 自动把上台选手字典传给实现了 DisplayPlayer(dict) 的节点。
    /// 节点名称含 "red"/"blue" 即按红蓝方分流，否则按当前主题显示对应一方。
    /// 图片下载复用 AvatarLoader（头像按 id 缓存，队徽/队伍照片按 URL 缓存），GIF 自动取首帧。
    /// </summary>
    public partial class PlayerImageField : Node2D
    {
        public enum ImageKind { Avatar, TeamLogo, TeamPhoto }

        [Export] public string BaseUrl = "https://lskb.cc.cd";
        [Export] public string AvatarLoaderPath = "/root/Main/AvatarLoader";
        [Export] public ImageKind Kind = ImageKind.Avatar;
        [Export] public bool UseTeamLogoAsFallback = true;   // 仅 Avatar 模式：头像缺失时回退队徽
        [Export] public int TargetWidth = 200;
        [Export] public int TargetHeight = 200;

        private TextureRect _image;
        private AvatarLoader _avatarLoader;
        private int _currentId = -1;
        private string _currentUrl = "";

        public override void _Ready()
        {
            _image = FindChild("Image", true, false) as TextureRect;
            EnsureAvatarLoader();
            ApplySize();
            Clear();
        }

        private void ApplySize()
        {
            if (_image == null) return;
            _image.OffsetRight = TargetWidth;
            _image.OffsetBottom = TargetHeight;
            // 扩展模式（KeepAspect）在 .tscn 中通过 expand_mode=4 设定，避免依赖枚举命名差异
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
                ImageKind.Avatar => "avatar",
                ImageKind.TeamLogo => "team_logo",
                ImageKind.TeamPhoto => "team_photo",
                _ => ""
            };

        private string Get(Godot.Collections.Dictionary player, string key)
        {
            if (player == null || !player.ContainsKey(key)) return "";
            Variant v = player[key];
            return v.VariantType == Variant.Type.Nil ? "" : v.ToString();
        }

        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (_image == null) return;
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

            _image.Texture = null;
            _image.Visible = false;

            if (string.IsNullOrEmpty(url))
            {
                // 无 URL 时尝试用本地缓存兜底
                var local = _avatarLoader.GetLocalAvatar(id);
                if (local != null)
                {
                    _image.Texture = local;
                    _image.Visible = true;
                }
                return;
            }

            _currentUrl = url;

            if (Kind == ImageKind.Avatar)
            {
                _avatarLoader.LoadAvatar(id, url,
                    (loadedId, tex) =>
                    {
                        if (loadedId != _currentId || _image == null) return;
                        _image.Texture = tex;
                        _image.Visible = true;
                    },
                    (loadedId, err) =>
                    {
                        if (loadedId != _currentId) return;
                        var local = _avatarLoader.GetLocalAvatar(id);
                        if (local != null && _image != null)
                        {
                            _image.Texture = local;
                            _image.Visible = true;
                        }
                    });
            }
            else
            {
                _avatarLoader.LoadImage(url,
                    tex =>
                    {
                        if (_currentUrl != url || _image == null) return;
                        _image.Texture = tex;
                        _image.Visible = true;
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
            if (_image != null)
            {
                _image.Texture = null;
                _image.Visible = false;
            }
        }
    }
}
