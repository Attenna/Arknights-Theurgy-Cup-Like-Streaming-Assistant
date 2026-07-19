using Godot;
using System;
using System.Collections.Generic;

namespace PlayerStatistics
{
    public partial class PlayerManager : Node
    {
        [Signal]
        public delegate void PlayerSelectedEventHandler(int playerId);

        [Signal]
        public delegate void PlayersUpdatedEventHandler();

        [Export] public string LocalDataPath = "user://data/players.json";
        [Export] public string LocalTeamsPath = "user://data/teams.json";

        private List<PlayerData> _players = new List<PlayerData>();
        private PlayerData _selectedPlayer = null;
        private string _lastSignature = "";

        public List<PlayerData> Players => _players;

        public PlayerData SelectedPlayer => _selectedPlayer;

        public override void _Ready()
        {
            EnsureDataDirectory();
            LoadFromLocal();

            // If no players were loaded from cache (first run / no network), seed defaults.
            if (_players.Count == 0)
            {
                SeedDefaultPlayers();
                GD.Print("[PlayerManager] Seeded default players for offline use");
            }
        }

        private void EnsureDataDirectory()
        {
            string dir = System.IO.Path.GetDirectoryName(ProjectSettings.GlobalizePath(LocalDataPath));
            if (!System.IO.Directory.Exists(dir))
            {
                System.IO.Directory.CreateDirectory(dir);
                GD.Print($"[PlayerManager] Created data directory: {dir}");
            }
        }

        public void LoadPlayers(Godot.Collections.Dictionary data)
        {
            var newPlayers = new List<PlayerData>();

            if (data.ContainsKey("players"))
            {
                var playersVar = data["players"];
                if (playersVar.VariantType == Variant.Type.Array)
                {
                    var playersArray = playersVar.AsGodotArray();
                    foreach (var playerVar in playersArray)
                    {
                        if (playerVar.VariantType == Variant.Type.Dictionary)
                        {
                            var playerDict = playerVar.AsGodotDictionary();
                            newPlayers.Add(PlayerData.FromDictionary(playerDict));
                        }
                    }
                }
            }

            // Skip the broadcast (and the resulting UI rebuild cascade) when the
            // incoming data is identical to what we already hold.
            string signature = ComputeSignature(newPlayers);
            if (signature == _lastSignature && _players.Count == newPlayers.Count)
            {
                GD.Print($"[PlayerManager] Player data unchanged ({newPlayers.Count} players), skipping update");
                return;
            }

            _players = newPlayers;
            _lastSignature = signature;
            GD.Print($"[PlayerManager] Loaded {_players.Count} players");
            EmitSignal("players_updated");
            SaveToLocal();
        }

        private string ComputeSignature(List<PlayerData> players)
        {
            long hash = players.Count;
            foreach (var p in players)
            {
                hash = (hash * 31 + p.Id)
                     ^ ((long)p.Rating * 7)
                     ^ p.Name.GetHashCode()
                     ^ p.TeamName.GetHashCode()
                     ^ p.Operator.GetHashCode()
                     ^ p.Roguelike.GetHashCode()
                     ^ p.Squad.GetHashCode()
                     ^ p.Declaration.GetHashCode()
                     ^ p.Opening.GetHashCode()
                     ^ ((long)p.FinalScore * 13);
            }
            return hash.ToString();
        }

        public void SelectPlayer(int index)
        {
            if (index >= 0 && index < _players.Count)
            {
                _selectedPlayer = _players[index];
                GD.Print($"[PlayerManager] Selected player: {_selectedPlayer.Name}");
                EmitSignal("player_selected", _selectedPlayer.Id);
            }
        }

        public void SelectPlayerById(int id)
        {
            var player = _players.Find(p => p.Id == id);
            if (player != null)
            {
                _selectedPlayer = player;
                GD.Print($"[PlayerManager] Selected player by ID: {player.Id} - {player.Name}");
                EmitSignal("player_selected", player.Id);
            }
        }

        public PlayerData GetPlayerById(int id)
        {
            return _players.Find(p => p.Id == id);
        }

        // Dictionary variant for GDScript interop (custom C# classes cannot cross the language boundary)
        public Godot.Collections.Dictionary GetPlayerDictionary(int id)
        {
            var player = _players.Find(p => p.Id == id);
            if (player == null) return null;
            return player.ToDictionary();
        }

        public List<PlayerData> SearchPlayers(string keyword)
        {
            if (string.IsNullOrEmpty(keyword))
            {
                return new List<PlayerData>(_players);
            }

            keyword = keyword.ToLower();
            return _players.FindAll(p =>
                p.Name.ToLower().Contains(keyword) ||
                p.Nickname.ToLower().Contains(keyword) ||
                p.School.ToLower().Contains(keyword) ||
                p.TeamName.ToLower().Contains(keyword) ||
                p.Operator.ToLower().Contains(keyword) ||
                p.Roguelike.ToLower().Contains(keyword) ||
                p.Declaration.ToLower().Contains(keyword) ||
                p.Opening.ToLower().Contains(keyword)
            );
        }

        public List<PlayerData> GetPlayersByTeam(int teamId)
        {
            return _players.FindAll(p => p.TeamId == teamId);
        }

        public void SaveToLocal()
        {
            try
            {
                var saveData = new Godot.Collections.Dictionary();
                var playersArray = new Godot.Collections.Array();
                
                foreach (var player in _players)
                {
                    playersArray.Add(player.ToDictionary());
                }
                
                saveData["players"] = playersArray;
                saveData["total"] = _players.Count;
                saveData["saved_at"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");

                string json = Json.Stringify(saveData);
                string path = ProjectSettings.GlobalizePath(LocalDataPath);
                
                using var file = FileAccess.Open(path, FileAccess.ModeFlags.Write);
                file.StoreString(json);
                file.Close();

                GD.Print($"[PlayerManager] Saved {_players.Count} players to {path}");
            }
            catch (System.Exception e)
            {
                GD.PrintErr($"[PlayerManager] ERROR saving to local: {e.Message}");
            }
        }

        public void LoadFromLocal()
        {
            try
            {
                string path = ProjectSettings.GlobalizePath(LocalDataPath);
                
                if (!FileAccess.FileExists(path))
                {
                    GD.Print($"[PlayerManager] Local data file not found: {path}");
                    return;
                }

                using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
                string json = file.GetAsText();
                file.Close();

                var saveData = Json.ParseString(json);
                
                if (saveData.VariantType == Variant.Type.Dictionary)
                {
                    var dict = saveData.AsGodotDictionary();
                    LoadPlayers(dict);
                    GD.Print($"[PlayerManager] Loaded {_players.Count} players from local storage");
                }
            }
            catch (System.Exception e)
            {
                GD.PrintErr($"[PlayerManager] ERROR loading from local: {e.Message}");
            }
        }

        // Seeds demo / default players so the UI works without any API or cached data.
        private void SeedDefaultPlayers()
        {
            _players.Clear();
            _players.Add(new PlayerData
            {
                Id = 1,
                Name = "coolbreath",
                Nickname = "某是傻逼又傻逼废啊",
                School = "LAHNA",
                TeamName = "Demo Team",
                Rating = 1200,
                Wins = 10,
                Losses = 5,
                Draws = 2
            });
            _players.Add(new PlayerData
            {
                Id = 2,
                Name = "Almond",
                Nickname = "我喜Almond(送苦特管Astraea)",
                School = "LAHNA",
                TeamName = "Blue Demo Team",
                Rating = 1150,
                Wins = 8,
                Losses = 7,
                Draws = 1
            });
            _players.Add(new PlayerData
            {
                Id = 3,
                Name = "1807",
                Nickname = "龅哥#1807(Aaa嗯哼叼叻哒)",
                School = "LAHNA",
                TeamName = "Red Demo Team",
                Rating = 1180,
                Wins = 9,
                Losses = 6,
                Draws = 0
            });
            _players.Add(new PlayerData
            {
                Id = 4,
                Name = "qwqe",
                Nickname = "",
                School = "",
                TeamName = "",
                Rating = 0,
                Wins = 0,
                Losses = 0,
                Draws = 0
            });

            SaveToLocal(); // Persist so next launch uses these too.
            _lastSignature = ComputeSignature(_players);
            EmitSignal("players_updated");
        }
    }

    public class PlayerData
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Nickname { get; set; } = "";
        public string School { get; set; } = "";   // squad 别名，向后兼容
        public string Squad { get; set; } = "";     // 分队（来自 team.squad）
        public int TeamId { get; set; }
        public string TeamName { get; set; } = "";
        public int Rating { get; set; }
        public int Wins { get; set; }
        public int Losses { get; set; }
        public int Draws { get; set; }
        public string AvatarUrl { get; set; } = "";
        public string TeamLogoUrl { get; set; } = "";

        // 新增：之前解析遗漏的队伍信息 / 附加信息
        public string Role { get; set; } = "";        // 角色：captain / member 等
        public string CreatedAt { get; set; } = "";   // 创建时间
        public string Operator { get; set; } = "";    // 运营 / 操作者
        public string Roguelike { get; set; } = "";   // 肉鸽模式，如 sarkaz
        public string TeamPhotoUrl { get; set; } = ""; // 队伍照片
        public int FinalScore { get; set; }           // 最终得分
        public string Declaration { get; set; } = ""; // 宣言
        public string Opening { get; set; } = "";     // 开局词

        // 兜底：原样保存所有未显式建模的字段，保证「解析不全」问题彻底解决
        private Godot.Collections.Dictionary _raw = new Godot.Collections.Dictionary();

        public static PlayerData FromDictionary(Godot.Collections.Dictionary dict)
        {
            var data = new PlayerData();
            if (dict == null) return data;

            // 1) 原样保存每一个顶层字段
            foreach (var kv in dict)
            {
                string k = kv.Key.ToString();
                if (!data._raw.ContainsKey(k))
                    data._raw[k] = kv.Value;
            }

            if (dict.ContainsKey("id")) data.Id = ToInt(dict["id"]);

            data.Name = FindFirstString(dict, "username", "name", "display_name");
            data.Nickname = FindFirstString(dict, "nickname", "alias", "display_name");
            data.AvatarUrl = FindFirstString(dict, "avatar", "avatar_url", "headshot", "photo", "image", "profile_image", "picture");
            data.Role = FindFirstString(dict, "role", "position", "title");
            data.CreatedAt = FindFirstString(dict, "created_at", "created", "registered_at");

            // 宣言 / 开局：优先在选手顶层查找，再回退到 team 层（兼容多种命名）
            data.Declaration = FindFirstString(dict, "declaration", "manifesto", "motto", "slogan", "signature", "self_intro", "intro", "bio", "description", "宣言");
            data.Opening = FindFirstString(dict, "opening", "opening_words", "opening_text", "first_line", "opening_remark", "开局");

            if (dict.ContainsKey("team") && dict["team"].VariantType == Variant.Type.Dictionary)
            {
                var teamDict = dict["team"].AsGodotDictionary();

                // 原样保存每一个 team 子字段（加 team_ 前缀避免键冲突）
                foreach (var kv in teamDict)
                {
                    string k = "team_" + kv.Key.ToString();
                    if (!data._raw.ContainsKey(k))
                        data._raw[k] = kv.Value;
                }

                if (teamDict.ContainsKey("id")) data.TeamId = ToInt(teamDict["id"]);
                if (teamDict.ContainsKey("name")) data.TeamName = teamDict["name"].ToString();
                if (teamDict.ContainsKey("squad")) { data.Squad = teamDict["squad"].ToString(); data.School = data.Squad; }

                if (string.IsNullOrEmpty(data.Declaration))
                    data.Declaration = FindFirstString(teamDict, "declaration", "manifesto", "motto", "slogan", "signature", "self_intro", "intro", "bio", "description", "宣言");
                if (string.IsNullOrEmpty(data.Opening))
                    data.Opening = FindFirstString(teamDict, "opening", "opening_words", "opening_text", "first_line", "opening_remark", "开局");

                // 开局干员（Operator 字段）：优先取选手自身顶层字段，回退到 team 层
                // （API 将 operator 等队伍信息直接嵌在每个 player 对象顶层）。
                data.Operator = FindFirstString(dict, "operator", "starting_operator", "opening_operator", "开局干员");
                if (string.IsNullOrEmpty(data.Operator))
                    data.Operator = FindFirstString(teamDict, "operator", "captain", "leader", "manager");
                data.Roguelike = FindFirstString(teamDict, "roguelike", "rogue", "mode", "theme");
                data.TeamPhotoUrl = FindFirstString(teamDict, "team_photo", "photo", "image", "avatar", "picture");
                if (teamDict.ContainsKey("final_score")) data.FinalScore = ToInt(teamDict["final_score"]);

                // 队徽：优先真实 logo，没有则回退到 team_photo
                data.TeamLogoUrl = FindFirstString(teamDict, "logo", "logo_url", "crest", "emblem", "icon", "team_photo", "avatar");
            }

            if (string.IsNullOrEmpty(data.TeamLogoUrl))
                data.TeamLogoUrl = FindFirstString(dict, "team_logo", "team_logo_url", "logo");

            return data;
        }

        private static int ToInt(Godot.Variant v)
        {
            if (v.VariantType == Variant.Type.Int) return (int)v;
            if (v.VariantType == Variant.Type.Float) return (int)(float)v;
            if (v.VariantType == Variant.Type.String && int.TryParse(v.ToString(), out int r)) return r;
            return 0;
        }

        // Returns the first non-empty string value found among the given keys.
        private static string FindFirstString(Godot.Collections.Dictionary dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (dict.ContainsKey(key) && dict[key].VariantType != Variant.Type.Nil)
                {
                    string value = dict[key].ToString();
                    if (!string.IsNullOrEmpty(value) && !value.Equals("null", StringComparison.OrdinalIgnoreCase))
                        return value;
                }
            }
            return "";
        }

        public double WinRate()
        {
            int total = Wins + Losses + Draws;
            if (total == 0) return 0;
            return (double)(Wins + Draws * 0.5) / total * 100;
        }

        public Godot.Collections.Dictionary ToDictionary()
        {
            var dict = new Godot.Collections.Dictionary();
            dict["id"] = Id;
            dict["username"] = Name;
            dict["nickname"] = Nickname;
            dict["avatar"] = string.IsNullOrEmpty(AvatarUrl) ? null : AvatarUrl;
            dict["team_logo"] = string.IsNullOrEmpty(TeamLogoUrl) ? null : TeamLogoUrl;
            dict["school"] = School;
            dict["squad"] = Squad;
            dict["team_id"] = TeamId;
            dict["team_name"] = TeamName;
            dict["rating"] = Rating;
            dict["wins"] = Wins;
            dict["losses"] = Losses;
            dict["draws"] = Draws;
            dict["role"] = Role;
            dict["created_at"] = CreatedAt;
            dict["operator"] = Operator;
            dict["roguelike"] = Roguelike;
            dict["team_photo"] = string.IsNullOrEmpty(TeamPhotoUrl) ? null : TeamPhotoUrl;
            dict["final_score"] = FinalScore;
            dict["declaration"] = Declaration;
            dict["opening"] = Opening;

            // 兜底：把任何未显式建模的原始字段一并带出（前向兼容，避免解析遗漏）
            foreach (var kv in _raw)
            {
                string k = kv.Key.ToString();
                if (!dict.ContainsKey(k))
                    dict[k] = kv.Value;
            }
            return dict;
        }
    }
}