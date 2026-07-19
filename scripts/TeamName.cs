using Godot;

public partial class TeamName : Label
{
	public override void _Ready()
	{
		ClearTeamName();
	}

	// 由 main.gd 调用，显示当前上台选手所属队伍名。
	// 注意：必须用 team_name（字符串字段），不能用 team —— 后者是原始嵌套字典
	//（含 final_score 等比分信息），直接 ToString 会变成看不懂的字典文本。
	// 只改文字，不做着色。
	public void DisplayPlayer(Godot.Collections.Dictionary player)
	{
		if (player == null || !player.ContainsKey("id"))
		{
			ClearTeamName();
			return;
		}

		string team = "";
		if (player.ContainsKey("team_name") && player["team_name"].VariantType != Variant.Type.Nil)
			team = player["team_name"].ToString();

		Text = team;
	}

	public void ClearTeamName()
	{
		Text = "";
	}
}
