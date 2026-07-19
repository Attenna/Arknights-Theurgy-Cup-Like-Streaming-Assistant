using Godot;

namespace PlayerStatistics
{
    /// <summary>
    /// 挂在 player_avatar.tscn 根节点(Node2D)上的选手头像显示器。
    /// main.gd 的 _apply_staged_players() 会在选手上台 / 主题切换时调用 DisplayPlayer(dict)，
    /// 由于本节点为“中性节点”，main.gd 会根据当前主题(current_mode)传入对应红/蓝选手，
    /// 因此本脚本只需负责把传入选手的头像加载到 Avatar TextureRect 上。
    /// </summary>
    public partial class PlayerAvatarDisplay : Node2D
    {
        [Export] public string BaseUrl = "https://lskb.cc.cd";
        [Export] public string AvatarLoaderPath = "/root/Main/AvatarLoader";
        [Export] public bool UseTeamLogoAsFallback = true;

        private TextureRect _avatar;
        private AvatarLoader _avatarLoader;
        private int _currentId = -1;

        public override void _Ready()
        {
            _avatar = FindChild("Avatar", true, false) as TextureRect;
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

        /// <summary>
        /// 由 main.gd 调用。player 需含 id / avatar / team_logo（与 PlayerManager.GetPlayerDictionary 输出一致）。
        /// 传 null 或无 id 时清空显示。
        /// </summary>
        public void DisplayPlayer(Godot.Collections.Dictionary player)
        {
            if (player == null || !player.ContainsKey("id"))
            {
                Clear();
                return;
            }

            int id = (int)player["id"];
            _currentId = id;

            string Get(string key) =>
                player.ContainsKey(key) && player[key].VariantType != Variant.Type.Nil
                    ? player[key].ToString()
                    : "";

            LoadImages(id, Get("avatar"), Get("team_logo"));
        }

        private void LoadImages(int id, string playerAvatar, string teamLogo)
        {
            if (_avatarLoader == null || _avatar == null) return;

            string playerUrl = ToAbsoluteUrl(playerAvatar);
            string teamUrl = ToAbsoluteUrl(teamLogo);

            if (string.IsNullOrEmpty(playerUrl) && UseTeamLogoAsFallback && !string.IsNullOrEmpty(teamUrl))
                playerUrl = teamUrl;

            _avatar.Texture = null;
            _avatar.Visible = false;

            if (!string.IsNullOrEmpty(playerUrl))
            {
                _avatarLoader.LoadAvatar(id, playerUrl,
                    (loadedId, tex) =>
                    {
                        if (loadedId != _currentId || _avatar == null) return;
                        _avatar.Texture = tex;
                        _avatar.Visible = true;
                    },
                    (loadedId, err) =>
                    {
                        if (loadedId != _currentId) return;
                        var local = _avatarLoader.GetLocalAvatar(id);
                        if (local != null && _avatar != null)
                        {
                            _avatar.Texture = local;
                            _avatar.Visible = true;
                        }
                    });
            }
            else
            {
                var local = _avatarLoader.GetLocalAvatar(id);
                if (local != null)
                {
                    _avatar.Texture = local;
                    _avatar.Visible = true;
                }
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
            if (_avatar != null)
            {
                _avatar.Texture = null;
                _avatar.Visible = false;
            }
        }
    }
}
