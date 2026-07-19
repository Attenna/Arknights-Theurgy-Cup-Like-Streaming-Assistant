using Godot;
using System.Collections.Generic;

namespace PlayerStatistics
{
    public partial class CommentatorManager : Node
    {
        [Signal]
        public delegate void CommentatorSelectedEventHandler(int commentatorId);

        [Signal]
        public delegate void CommentatorsUpdatedEventHandler();

        private List<CommentatorData> _commentators = new List<CommentatorData>();
        private CommentatorData _selectedCommentator = null;

        public List<CommentatorData> Commentators => _commentators;

        public CommentatorData SelectedCommentator => _selectedCommentator;

        public void LoadCommentators(Godot.Collections.Dictionary data)
        {
            _commentators.Clear();

            if (data.ContainsKey("commentators"))
            {
                var commentatorsVar = data["commentators"];
                if (commentatorsVar.VariantType == Variant.Type.Array)
                {
                    var commentatorsArray = commentatorsVar.AsGodotArray();
                    foreach (var commentatorVar in commentatorsArray)
                    {
                        if (commentatorVar.VariantType == Variant.Type.Dictionary)
                        {
                            var commentatorDict = commentatorVar.AsGodotDictionary();
                            _commentators.Add(CommentatorData.FromDictionary(commentatorDict));
                        }
                    }
                }
            }
            else if (data.ContainsKey("players"))
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
                            bool isCommentator = false;
                            if (playerDict.ContainsKey("is_commentator"))
                            {
                                isCommentator = (bool)playerDict["is_commentator"];
                            }

                            if (isCommentator)
                            {
                                _commentators.Add(CommentatorData.FromPlayerDictionary(playerDict));
                            }
                        }
                    }
                }
            }

            GD.Print($"[CommentatorManager] Loaded {_commentators.Count} commentators");
            EmitSignal("commentators_updated");
        }

        public void SelectCommentator(int index)
        {
            if (index >= 0 && index < _commentators.Count)
            {
                _selectedCommentator = _commentators[index];
                GD.Print($"[CommentatorManager] Selected commentator: {_selectedCommentator.Name}");
                EmitSignal("commentator_selected", _selectedCommentator.Id);
            }
        }

        public void SelectCommentatorById(int id)
        {
            var commentator = _commentators.Find(c => c.Id == id);
            if (commentator != null)
            {
                _selectedCommentator = commentator;
                GD.Print($"[CommentatorManager] Selected commentator by ID: {commentator.Id} - {commentator.Name}");
                EmitSignal("commentator_selected", commentator.Id);
            }
        }

        public CommentatorData GetCommentatorById(int id)
        {
            return _commentators.Find(c => c.Id == id);
        }

        // Dictionary variant for GDScript interop (custom C# classes cannot cross the language boundary)
        public Godot.Collections.Dictionary GetCommentatorDictionary(int id)
        {
            var commentator = _commentators.Find(c => c.Id == id);
            if (commentator == null) return null;
            return commentator.ToDictionary();
        }

        public List<CommentatorData> SearchCommentators(string keyword)
        {
            if (string.IsNullOrEmpty(keyword))
            {
                return new List<CommentatorData>(_commentators);
            }

            keyword = keyword.ToLower();
            return _commentators.FindAll(c =>
                c.Name.ToLower().Contains(keyword) ||
                c.Nickname.ToLower().Contains(keyword)
            );
        }
    }

    public class CommentatorData
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Nickname { get; set; } = "";
        public string Title { get; set; } = "";
        public string Description { get; set; } = "";
        public int ExperienceYears { get; set; }

        public static CommentatorData FromDictionary(Godot.Collections.Dictionary dict)
        {
            var data = new CommentatorData();

            if (dict.ContainsKey("id"))
                data.Id = (int)dict["id"];

            if (dict.ContainsKey("name"))
                data.Name = dict["name"].ToString();

            if (dict.ContainsKey("nickname"))
                data.Nickname = dict["nickname"].ToString();

            if (dict.ContainsKey("title"))
                data.Title = dict["title"].ToString();

            if (dict.ContainsKey("description"))
                data.Description = dict["description"].ToString();

            if (dict.ContainsKey("experience_years"))
                data.ExperienceYears = (int)dict["experience_years"];

            return data;
        }

        public static CommentatorData FromPlayerDictionary(Godot.Collections.Dictionary dict)
        {
            var data = new CommentatorData();

            if (dict.ContainsKey("id"))
                data.Id = (int)dict["id"];

            if (dict.ContainsKey("name"))
                data.Name = dict["name"].ToString();

            if (dict.ContainsKey("nickname"))
                data.Nickname = dict["nickname"].ToString();

            if (dict.ContainsKey("school"))
                data.Title = dict["school"].ToString();

            return data;
        }

        public Godot.Collections.Dictionary ToDictionary()
        {
            var dict = new Godot.Collections.Dictionary();
            dict["id"] = Id;
            dict["name"] = Name;
            dict["nickname"] = Nickname;
            dict["title"] = Title;
            dict["description"] = Description;
            dict["experience_years"] = ExperienceYears;
            return dict;
        }
    }
}
