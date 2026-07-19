using Godot;

namespace PlayerStatistics
{
    public partial class CommentatorInfoDisplay : Control
    {
        [Export] public string NameLabelPath = "NameLabel";
        [Export] public string NicknameLabelPath = "NicknameLabel";
        [Export] public string TitleLabelPath = "TitleLabel";
        [Export] public string DescriptionLabelPath = "DescriptionLabel";
        [Export] public string ExperienceLabelPath = "ExperienceLabel";

        private Label _nameLabel;
        private Label _nicknameLabel;
        private Label _titleLabel;
        private Label _descriptionLabel;
        private Label _experienceLabel;

        public override void _Ready()
        {
            _nameLabel = GetNodeOrNull<Label>(NameLabelPath);
            _nicknameLabel = GetNodeOrNull<Label>(NicknameLabelPath);
            _titleLabel = GetNodeOrNull<Label>(TitleLabelPath);
            _descriptionLabel = GetNodeOrNull<Label>(DescriptionLabelPath);
            _experienceLabel = GetNodeOrNull<Label>(ExperienceLabelPath);

            Clear();
        }

        public void DisplayCommentator(Godot.Collections.Dictionary commentator)
        {
            if (commentator == null || !commentator.ContainsKey("id"))
            {
                Clear();
                return;
            }

            string Get(string key, string fallback) =>
                commentator.ContainsKey(key) ? commentator[key].ToString() : fallback;

            if (_nameLabel != null)
                _nameLabel.Text = Get("name", "-");

            if (_nicknameLabel != null)
                _nicknameLabel.Text = string.IsNullOrEmpty(Get("nickname", "")) ? "-" : Get("nickname", "");

            if (_titleLabel != null)
                _titleLabel.Text = string.IsNullOrEmpty(Get("title", "")) ? "-" : Get("title", "");

            if (_descriptionLabel != null)
                _descriptionLabel.Text = string.IsNullOrEmpty(Get("description", "")) ? "-" : Get("description", "");

            if (_experienceLabel != null)
            {
                int years = commentator.ContainsKey("experience_years") ? (int)commentator["experience_years"] : 0;
                _experienceLabel.Text = years > 0 ? $"{years}年解说经验" : "-";
            }

            GD.Print($"[CommentatorInfoDisplay] Displaying commentator: {Get("name", "")}");
        }

        public void Clear()
        {
            if (_nameLabel != null)
                _nameLabel.Text = "-";

            if (_nicknameLabel != null)
                _nicknameLabel.Text = "-";

            if (_titleLabel != null)
                _titleLabel.Text = "-";

            if (_descriptionLabel != null)
                _descriptionLabel.Text = "-";

            if (_experienceLabel != null)
                _experienceLabel.Text = "-";
        }

        public void UpdateWithMode(string mode)
        {
            Color accentColor = mode == "Red" ? new Color(1, 0.3f, 0.3f) : new Color(0.223f, 0.571f, 0.771f);

            UpdateLabelColor(_nameLabel, accentColor);
            UpdateLabelColor(_titleLabel, accentColor);
        }

        private void UpdateLabelColor(Label label, Color color)
        {
            if (label != null)
            {
                label.AddThemeColorOverride("font_color", color);
            }
        }
    }
}
