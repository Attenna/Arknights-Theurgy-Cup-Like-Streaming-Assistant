using Godot;
using System;
using System.Text;
using System.Text.RegularExpressions;

namespace PlayerStatistics
{
    /// <summary>
    /// 赛事大厅（/tournament/）HTTP 客户端。
    /// 该页面为公开页面，无需登录；直接 GET 后解析 HTML 提取赛事进度。
    /// 解析结果通过 tournament_updated 信号以 Godot Dictionary 形式抛出。
    /// </summary>
    public partial class TournamentApiClient : Node
    {
        [Export] public string BaseUrl = "https://lskb.cc.cd";
        [Export] public int RequestTimeout = 15;

        [Signal]
        public delegate void tournament_updatedEventHandler(Godot.Collections.Dictionary data);

        [Signal]
        public delegate void tournament_errorEventHandler(string error);

        private HttpRequest _httpRequest;
        private bool _busy = false;
        private Godot.Collections.Dictionary _lastData;

        public override void _Ready()
        {
            _httpRequest = new HttpRequest();
            AddChild(_httpRequest);
            _httpRequest.Timeout = RequestTimeout;
            _httpRequest.MaxRedirects = 8;
            _httpRequest.RequestCompleted += OnRequestCompleted;
            GD.Print("[TournamentApiClient] ready, BaseUrl=", BaseUrl);
        }

        /// <summary>主动向服务器拉取一次赛事状态。</summary>
        public void RequestStatus()
        {
            if (_busy)
            {
                GD.Print("[TournamentApiClient] 已有请求进行中，忽略本次调用");
                return;
            }
            if (_httpRequest == null)
            {
                EmitSignal("tournament_error", "HTTPRequest 尚未就绪");
                return;
            }

            _busy = true;
            string url = BaseUrl + "/tournament/";
            GD.Print("[TournamentApiClient] GET ", url);
            Error err = _httpRequest.Request(url);
            if (err != Error.Ok)
            {
                _busy = false;
                GD.PrintErr("[TournamentApiClient] 请求发起失败: ", err);
                EmitSignal("tournament_error", $"请求发起失败: {err}");
            }
        }

        /// <summary>返回上一次成功解析的数据（无则为空字典）。</summary>
        public Godot.Collections.Dictionary GetLastData()
        {
            return _lastData ?? new Godot.Collections.Dictionary();
        }

        private void OnRequestCompleted(long result, long responseCode, string[] headers, byte[] body)
        {
            _busy = false;

            bool isSuccess = result == (long)HttpRequest.Result.Success;
            if (!isSuccess || responseCode != 200)
            {
                GD.PrintErr($"[TournamentApiClient] 请求失败: result={result} code={responseCode}");
                EmitSignal("tournament_error", $"HTTP {responseCode}（result={result}）");
                return;
            }

            try
            {
                string html = Encoding.UTF8.GetString(body);
                Godot.Collections.Dictionary data = ParseTournamentHtml(html);
                _lastData = data;
                EmitSignal("tournament_updated", data);
            }
            catch (Exception e)
            {
                GD.PrintErr("[TournamentApiClient] 解析异常: ", e.Message);
                EmitSignal("tournament_error", $"解析异常: {e.Message}");
            }
        }

        private Godot.Collections.Dictionary ParseTournamentHtml(string html)
        {
            var data = new Godot.Collections.Dictionary();

            // 赛事名称：赛事大厅标题下方的 <p class="text-muted">冷水坑杯 #3</p>
            Match mName = Regex.Match(html, @"<p class=""text-muted"">([^<]+)</p>", RegexOptions.IgnoreCase);
            data["name"] = mName.Success ? mName.Groups[1].Value.Trim() : "";

            // 赛事状态：<h3><span class="badge ...">报名阶段</span></h3>
            Match mStatus = Regex.Match(html, @"<h3>\s*<span class=""badge[^""]*"">([^<]+)</span>\s*</h3>", RegexOptions.IgnoreCase);
            data["status"] = mStatus.Success ? mStatus.Groups[1].Value.Trim() : "";

            // 状态说明：<p class="text-muted mt-2">报名进行中，比赛尚未开始</p>
            Match mNote = Regex.Match(html, @"<p class=""text-muted mt-2"">([^<]+)</p>", RegexOptions.IgnoreCase);
            data["status_note"] = mNote.Success ? mNote.Groups[1].Value.Trim() : "";

            // 加成倍率：加成倍率：×500
            Match mBonus = Regex.Match(html, @"加成倍率：×(\d+)", RegexOptions.IgnoreCase);
            data["bonus_multiplier"] = mBonus.Success ? mBonus.Groups[1].Value : "";

            // 比赛统计：<h3 ...>数字</h3><small class="text-muted">标签</small>
            var stats = new Godot.Collections.Dictionary();
            foreach (Match mt in Regex.Matches(html,
                @"<h3[^>]*>\s*([\d,]+)\s*</h3>\s*<small class=""text-muted"">([^<]+)</small>",
                RegexOptions.IgnoreCase))
            {
                stats[mt.Groups[2].Value.Trim()] = mt.Groups[1].Value.Trim();
            }
            data["stats"] = stats;

            // 排行榜：<a href="/team/ID">队伍名</a> ... <strong>积分</strong>
            var leaderboard = new Godot.Collections.Array();
            int rank = 0;
            foreach (Match mt in Regex.Matches(html,
                @"<a href=""/team/(\d+)"">([^<]+)</a>\s*</td>\s*<td>\s*<strong>([\d,]+)</strong>\s*</td>",
                RegexOptions.IgnoreCase))
            {
                rank++;
                var row = new Godot.Collections.Dictionary();
                row["rank"] = rank;
                row["team_id"] = mt.Groups[1].Value;
                row["team"] = mt.Groups[2].Value.Trim();
                row["points"] = mt.Groups[3].Value.Trim();
                leaderboard.Add(row);
            }
            data["leaderboard"] = leaderboard;

            // 晋级区：<h5>晋级区</h5> ... <div class="card-body">内容</div>
            Match mAdv = Regex.Match(html,
                @"晋级区</h5>.+?<div class=""card-body"">\s*(.+?)\s*</div>",
                RegexOptions.IgnoreCase | RegexOptions.Singleline);
            if (mAdv.Success)
            {
                string advance = Regex.Replace(mAdv.Groups[1].Value, @"<[^>]+>", "").Trim();
                data["advance"] = advance;
            }
            else
            {
                data["advance"] = "";
            }

            data["fetched_at"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            return data;
        }
    }
}
