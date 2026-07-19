using Godot;
using System;
using System.Text;
using System.Text.RegularExpressions;

namespace PlayerStatistics
{
    public partial class PlayerApiClient : Node
    {
        [Export] public string BaseUrl = "https://lskb.cc.cd";
        [Export] public string CredentialsPath = "user://config/credentials.txt";
        [Export] public int RequestTimeout = 15;

        [Signal]
        public delegate void players_loadedEventHandler(Godot.Collections.Dictionary data);

        [Signal]
        public delegate void LoadFailedEventHandler(string error);

        private HttpRequest _httpRequest;
        private string _csrfToken = "";
        private string _username = "";
        private string _password = "";
        private string _cookieHeader = "";
        private string _loginActionUrl = "";

        // 默认同步账号（仅作登录框预填，凭据文件中已配置时优先使用文件中的值）。
        // 用户名 = Endmin，密码 = Astrid258（无空格）。密码仍需通过
        // user://config/credentials.txt 提供（该文件不入库）。
        public const string DefaultSyncUsername = "Endmin";
        public const string DefaultSyncPassword = "Astrid258";

        private enum RequestState
        {
            Idle,
            GetCsrf,
            Login,
            FetchPlayers
        }

        private RequestState _state = RequestState.Idle;
        private Godot.Collections.Dictionary _playersData;

        public override void _Ready()
        {
            GD.Print("=========================================");
            GD.Print("[PlayerApiClient] _Ready() called");
            GD.Print("[PlayerApiClient] BaseUrl: ", BaseUrl);
            GD.Print("[PlayerApiClient] RequestTimeout: ", RequestTimeout);
            
            _httpRequest = GetNode<HttpRequest>("HTTPRequest");
            GD.Print("[PlayerApiClient] HTTPRequest node found: ", _httpRequest != null);
            
            if (_httpRequest != null)
            {
                _httpRequest.Timeout = RequestTimeout;
                _httpRequest.MaxRedirects = 0;
                _httpRequest.RequestCompleted += OnRequestCompleted;
                GD.Print("[PlayerApiClient] HTTPRequest timeout set to: ", _httpRequest.Timeout);
                GD.Print("[PlayerApiClient] HTTPRequest MaxRedirects set to: ", _httpRequest.MaxRedirects);
                GD.Print("[PlayerApiClient] RequestCompleted signal connected");
            }

            LoadCredentials();
            
            GD.Print("[PlayerApiClient] _Ready() completed");
            GD.Print("=========================================");
        }

        private void LoadCredentials()
        {
            GD.Print("[PlayerApiClient] LoadCredentials() called");
            GD.Print("[PlayerApiClient] CredentialsPath: ", CredentialsPath);
            
            string resolvedPath = ProjectSettings.GlobalizePath(CredentialsPath);

            if (!FileAccess.FileExists(resolvedPath))
            {
                GD.PrintErr($"[PlayerApiClient] Credentials file NOT found: {CredentialsPath}");
                GD.Print("[PlayerApiClient] Will wait for runtime credentials");
                return;
            }

            GD.Print("[PlayerApiClient] Credentials file exists, reading...");
            
            using (var file = FileAccess.Open(resolvedPath, FileAccess.ModeFlags.Read))
            {
                string content = file.GetAsText();
                GD.Print("[PlayerApiClient] File content length: ", content.Length);
                
                string[] lines = content.Split('\n');
                GD.Print("[PlayerApiClient] Number of lines: ", lines.Length);
                
                foreach (string line in lines)
                {
                    string trimmed = line.Trim();
                    if (trimmed.StartsWith("username="))
                    {
                        _username = trimmed.Substring(9);
                        GD.Print("[PlayerApiClient] Username loaded: ", _username);
                    }
                    else if (trimmed.StartsWith("password="))
                    {
                        _password = trimmed.Substring(9);
                        GD.Print("[PlayerApiClient] Password loaded (length: ", _password.Length, ")");
                    }
                }
            }

            if (string.IsNullOrEmpty(_username) || string.IsNullOrEmpty(_password))
            {
                GD.PrintErr("[PlayerApiClient] Invalid credentials in file - username or password empty");
            }
            else
            {
                GD.Print("[PlayerApiClient] Credentials loaded successfully");
            }
        }

        public void SetCredentials(string username, string password)
        {
            _username = username;
            _password = password;
            GD.Print("=========================================");
            GD.Print("[PlayerApiClient] SetCredentials() called");
            GD.Print("[PlayerApiClient] Username: ", username);
            GD.Print("[PlayerApiClient] Password length: ", password.Length);
            GD.Print("[PlayerApiClient] HasCredentials() = ", HasCredentials());
            GD.Print("=========================================");
        }

        public bool HasCredentials()
        {
            return !string.IsNullOrEmpty(_username) && !string.IsNullOrEmpty(_password);
        }

        public void FetchPlayers()
        {
            GD.Print("=========================================");
            GD.Print("[PlayerApiClient] FetchPlayers() called");
            
            if (_state != RequestState.Idle)
            {
                GD.Print("[PlayerApiClient] WARNING: A request is already in progress! Current state: ", _state);
                return;
            }

            if (!HasCredentials())
            {
                GD.PrintErr("[PlayerApiClient] ERROR: No credentials provided! Please login first");
                EmitSignal("load_failed", "No credentials provided! Please enter username and password");
                return;
            }

            if (_httpRequest == null)
            {
                GD.PrintErr("[PlayerApiClient] ERROR: HTTPRequest node not found!");
                EmitSignal("load_failed", "HTTPRequest node not found");
                return;
            }

            GD.Print("[PlayerApiClient] HTTPRequest is ready");
            GD.Print("[PlayerApiClient] Credentials are ready");
            GD.Print("[PlayerApiClient] Transitioning state to GetCsrf");
            
            _state = RequestState.GetCsrf;

            string url = BaseUrl + "/auth/login";
            GD.Print("[PlayerApiClient] Requesting login page URL: ", url);
            
            Error err = _httpRequest.Request(url);
            GD.Print("[PlayerApiClient] GetCsrf request() returned: ", err);
            
            GD.Print("=========================================");
        }

        private void OnRequestCompleted(long result, long responseCode, string[] headers, byte[] body)
        {
            GD.Print("=========================================");
            GD.Print("[PlayerApiClient] OnRequestCompleted() called");
            GD.Print("[PlayerApiClient] Current state: ", _state);
            GD.Print("[PlayerApiClient] Result: ", result, " (Success=", (long)HttpRequest.Result.Success, ")");
            GD.Print("[PlayerApiClient] ResponseCode: ", responseCode);
            GD.Print("[PlayerApiClient] Headers count: ", headers?.Length ?? 0);
            GD.Print("[PlayerApiClient] Body length: ", body?.Length ?? 0);
            
            if (headers != null)
            {
                GD.Print("[PlayerApiClient] --- Response Headers ---");
                foreach (string header in headers)
                {
                    if (header.StartsWith("set-cookie:", StringComparison.OrdinalIgnoreCase))
                    {
                        GD.Print("[PlayerApiClient]   ", header.Substring(0, Math.Min(header.Length, 100)));
                    }
                    else
                    {
                        GD.Print("[PlayerApiClient]   ", header);
                    }
                }
                GD.Print("[PlayerApiClient] --- End Headers ---");
            }

            bool isSuccess = result == (long)HttpRequest.Result.Success;
            bool isRedirectLimitReached = result == (long)HttpRequest.Result.RedirectLimitReached;
            
            if (!isSuccess && !isRedirectLimitReached)
            {
                GD.PrintErr("[PlayerApiClient] ERROR: Request failed!");
                GD.PrintErr("[PlayerApiClient] Result code: ", result);
                EmitSignal("load_failed", $"Request failed: result={result} (see console for details)");
                _state = RequestState.Idle;
                GD.Print("=========================================");
                return;
            }

            GD.Print("[PlayerApiClient] Request result: ", isSuccess ? "Success" : "RedirectLimitReached (expected for login)");
            GD.Print("[PlayerApiClient] Processing response...");

            switch (_state)
            {
                case RequestState.GetCsrf:
                    GD.Print("[PlayerApiClient] -> Handling CSRF response");
                    HandleCsrfResponse(responseCode, headers, body);
                    break;
                case RequestState.Login:
                    GD.Print("[PlayerApiClient] -> Handling Login response");
                    HandleLoginResponse(responseCode, headers, body);
                    break;
                case RequestState.FetchPlayers:
                    GD.Print("[PlayerApiClient] -> Handling Players response");
                    HandlePlayersResponse(responseCode, body);
                    break;
                default:
                    GD.PrintErr("[PlayerApiClient] ERROR: Unknown state: ", _state);
                    _state = RequestState.Idle;
                    break;
            }
            
            GD.Print("=========================================");
        }

        private void HandleCsrfResponse(long responseCode, string[] headers, byte[] body)
        {
            GD.Print("[PlayerApiClient] HandleCsrfResponse() called");
            GD.Print("[PlayerApiClient] ResponseCode: ", responseCode);

            if (responseCode != 200)
            {
                GD.PrintErr("[PlayerApiClient] ERROR: Failed to get CSRF, HTTP ", responseCode);
                EmitSignal("load_failed", $"Failed to get CSRF: HTTP {responseCode}");
                _state = RequestState.Idle;
                return;
            }

            _cookieHeader = "";
            if (headers != null)
            {
                foreach (string header in headers)
                {
                    if (header.StartsWith("set-cookie:", StringComparison.OrdinalIgnoreCase))
                    {
                        string cookieValue = header.Substring(11).Trim();
                        int semicolonIndex = cookieValue.IndexOf(';');
                        if (semicolonIndex > 0)
                        {
                            cookieValue = cookieValue.Substring(0, semicolonIndex).Trim();
                        }
                        _cookieHeader = string.IsNullOrEmpty(_cookieHeader) ? cookieValue : _cookieHeader + "; " + cookieValue;
                    }
                }
            }

            GD.Print("[PlayerApiClient] Initial cookie: ", string.IsNullOrEmpty(_cookieHeader) ? "NONE" : _cookieHeader);

            GD.Print("[PlayerApiClient] HTTP 200 OK, extracting CSRF token...");

            string html = Encoding.UTF8.GetString(body);
            GD.Print("[PlayerApiClient] HTML content length: ", html.Length);
            
            if (html.Length > 0)
            {
                GD.Print("[PlayerApiClient] First 500 chars of HTML: ", html.Substring(0, Math.Min(500, html.Length)));
                
                int formStart = html.IndexOf("<form", StringComparison.OrdinalIgnoreCase);
                if (formStart >= 0)
                {
                    int formEnd = html.IndexOf("</form>", formStart, StringComparison.OrdinalIgnoreCase);
                    if (formEnd >= 0)
                    {
                        string formHtml = html.Substring(formStart, formEnd - formStart + 7);
                        GD.Print("[PlayerApiClient] Form HTML: ", formHtml);
                    }
                }
            }

            _csrfToken = ExtractCsrfToken(html);
            GD.Print("[PlayerApiClient] Extracted CSRF token: ", string.IsNullOrEmpty(_csrfToken) ? "NULL/EMPTY" : _csrfToken);

            _loginActionUrl = ExtractLoginActionUrl(html);
            GD.Print("[PlayerApiClient] Extracted login action URL: ", string.IsNullOrEmpty(_loginActionUrl) ? "NULL/EMPTY" : _loginActionUrl);

            if (string.IsNullOrEmpty(_csrfToken))
            {
                GD.PrintErr("[PlayerApiClient] ERROR: Failed to extract CSRF token from HTML");
                EmitSignal("load_failed", "Failed to extract CSRF token");
                _state = RequestState.Idle;
                return;
            }

            if (string.IsNullOrEmpty(_loginActionUrl))
            {
                GD.Print("[PlayerApiClient] WARNING: No login action URL found, using default /auth/login");
                _loginActionUrl = "/auth/login";
            }

            GD.Print("[PlayerApiClient] CSRF token obtained successfully!");
            GD.Print("[PlayerApiClient] Transitioning state to Login");
            
            _state = RequestState.Login;

            string postData = $"username={Uri.EscapeDataString(_username)}&password={Uri.EscapeDataString(_password)}&csrf_token={Uri.EscapeDataString(_csrfToken)}";
            GD.Print("[PlayerApiClient] Post data: ", postData);

            string[] postHeaders = { 
                "Content-Type: application/x-www-form-urlencoded", 
                "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
                "Referer: " + BaseUrl + "/auth/login",
                "Origin: " + BaseUrl
            };
            
            if (!string.IsNullOrEmpty(_cookieHeader))
            {
                Array.Resize(ref postHeaders, postHeaders.Length + 1);
                postHeaders[postHeaders.Length - 1] = "Cookie: " + _cookieHeader;
            }

            string loginUrl = _loginActionUrl.StartsWith("http") ? _loginActionUrl : BaseUrl + _loginActionUrl;
            GD.Print("[PlayerApiClient] ====== LOGIN REQUEST DETAILS ======");
            GD.Print("[PlayerApiClient] URL: ", loginUrl);
            GD.Print("[PlayerApiClient] Method: POST");
            GD.Print("[PlayerApiClient] PostData length: ", postData.Length);
            GD.Print("[PlayerApiClient] Headers count: ", postHeaders.Length);
            foreach (string h in postHeaders)
            {
                GD.Print("[PlayerApiClient]   Header: ", h);
            }
            GD.Print("[PlayerApiClient] ==================================");
            
            Error err = _httpRequest.Request(loginUrl, postHeaders, Godot.HttpClient.Method.Post, postData);
            GD.Print("[PlayerApiClient] Login request() returned: ", err);
        }

        private string ExtractCsrfToken(string html)
        {
            string[] patterns = {
                @"meta\s+name=""csrf-token""\s+content=""([^""]+)""",
                @"meta\s+content=""([^""]+)""\s+name=""csrf-token""",
                @"input\s+type=""hidden""\s+name=""csrf_token""\s+value=""([^""]+)""",
                @"input\s+type=""hidden""\s+value=""([^""]+)""\s+name=""csrf_token""",
                @"input\s+type=""hidden""\s+name=""csrf-token""\s+value=""([^""]+)""",
                @"input\s+type=""hidden""\s+value=""([^""]+)""\s+name=""csrf-token"""
            };

            foreach (string pattern in patterns)
            {
                Match match = Regex.Match(html, pattern, RegexOptions.IgnoreCase);
                if (match.Success)
                {
                    GD.Print("[PlayerApiClient] CSRF token matched pattern: ", pattern);
                    return match.Groups[1].Value;
                }
            }

            GD.PrintErr("[PlayerApiClient] No CSRF token pattern matched");
            return "";
        }

        private string ExtractLoginActionUrl(string html)
        {
            string[] patterns = {
                @"<form\s+[^>]*action=""([^""]+)""",
                @"<form\s+action=""([^""]+)""",
                @"<form\s+method=""post""\s+[^>]*action=""([^""]+)""",
                @"<form\s+method=""post""\s+action=""([^""]+)""",
                @"<form\s+[^>]*action='([^']+)'",
                @"<form\s+action='([^']+)'",
                @"<form\s+method='post'\s+[^>]*action='([^']+)'",
                @"<form\s+method='post'\s+action='([^']+)'"
            };

            foreach (string pattern in patterns)
            {
                Match match = Regex.Match(html, pattern, RegexOptions.IgnoreCase);
                if (match.Success)
                {
                    GD.Print("[PlayerApiClient] Login action URL matched pattern: ", pattern);
                    return match.Groups[1].Value;
                }
            }

            // 未解析到显式 action 属正常情况（表单默认提交到当前页面），
            // 这里只是提示，调用方会回退到默认的 /auth/login。
            GD.Print("[PlayerApiClient] No login action URL matched, falling back to /auth/login");
            return "";
        }

        private void HandleLoginResponse(long responseCode, string[] headers, byte[] body)
        {
            GD.Print("[PlayerApiClient] HandleLoginResponse() called");
            GD.Print("[PlayerApiClient] ResponseCode: ", responseCode);

            bool hasSessionCookie = false;
            string locationHeader = "";

            if (headers != null)
            {
                GD.Print("[PlayerApiClient] Checking for session cookies and Location header...");
                foreach (string header in headers)
                {
                    if (header.StartsWith("set-cookie:", StringComparison.OrdinalIgnoreCase))
                    {
                        GD.Print("[PlayerApiClient] Found Set-Cookie: ", header.Substring(0, Math.Min(header.Length, 150)));
                        string cookieValue = header.Substring(11).Trim();
                        int semicolonIndex = cookieValue.IndexOf(';');
                        if (semicolonIndex > 0)
                        {
                            cookieValue = cookieValue.Substring(0, semicolonIndex).Trim();
                        }
                        
                        if (cookieValue.Contains("session="))
                        {
                            hasSessionCookie = true;
                        }
                        
                        if (_cookieHeader.Contains(cookieValue.Split('=')[0] + "="))
                        {
                            string oldCookie = _cookieHeader;
                            _cookieHeader = "";
                            string[] cookies = oldCookie.Split(';');
                            foreach (string c in cookies)
                            {
                                string trimmed = c.Trim();
                                if (!trimmed.StartsWith(cookieValue.Split('=')[0] + "="))
                                {
                                    _cookieHeader = string.IsNullOrEmpty(_cookieHeader) ? trimmed : _cookieHeader + "; " + trimmed;
                                }
                            }
                        }
                        
                        _cookieHeader = string.IsNullOrEmpty(_cookieHeader) ? cookieValue : _cookieHeader + "; " + cookieValue;
                    }
                    else if (header.StartsWith("location:", StringComparison.OrdinalIgnoreCase))
                    {
                        locationHeader = header.Substring(9).Trim();
                        GD.Print("[PlayerApiClient] Found Location: ", locationHeader);
                    }
                }
            }

            bool isRedirect = responseCode == 301 || responseCode == 302 || responseCode == 303;
            GD.Print("[PlayerApiClient] Is redirect: ", isRedirect);
            GD.Print("[PlayerApiClient] Has session cookie: ", hasSessionCookie);
            GD.Print("[PlayerApiClient] Location header: ", string.IsNullOrEmpty(locationHeader) ? "NONE" : locationHeader);

            if (!isRedirect)
            {
                GD.PrintErr("[PlayerApiClient] ERROR: Login failed - expected redirect (301/302/303), got ", responseCode);
                GD.PrintErr("[PlayerApiClient] Location header: ", string.IsNullOrEmpty(locationHeader) ? "NONE" : locationHeader);
                
                string html = body != null ? Encoding.UTF8.GetString(body) : "";
                if (html.Length > 0 && html.Length < 1000)
                {
                    GD.PrintErr("[PlayerApiClient] Response body: ", html);
                }
                
                EmitSignal("load_failed", $"Login failed: HTTP {responseCode}, please check username and password");
                _state = RequestState.Idle;
                return;
            }

            GD.Print("[PlayerApiClient] ✓ Login successful!");
            GD.Print("[PlayerApiClient] Has session cookie: ", hasSessionCookie);
            GD.Print("[PlayerApiClient] Cookie header to send: ", string.IsNullOrEmpty(_cookieHeader) ? "EMPTY" : _cookieHeader.Substring(0, Math.Min(_cookieHeader.Length, 100)));
            GD.Print("[PlayerApiClient] Transitioning state to FetchPlayers");
            
            _state = RequestState.FetchPlayers;

            string[] getHeaders = { 
                "Accept: application/json", 
                "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" 
            };
            
            if (!string.IsNullOrEmpty(_cookieHeader))
            {
                Array.Resize(ref getHeaders, getHeaders.Length + 1);
                getHeaders[getHeaders.Length - 1] = "Cookie: " + _cookieHeader;
            }
            
            string playersUrl = "https://lskb.cc.cd/player/api/players";
            GD.Print("[PlayerApiClient] Requesting players URL: ", playersUrl);
            
            Error err = _httpRequest.Request(playersUrl, getHeaders);
            GD.Print("[PlayerApiClient] FetchPlayers request() returned: ", err);
        }

        private void HandlePlayersResponse(long responseCode, byte[] body)
        {
            GD.Print("[PlayerApiClient] HandlePlayersResponse() called");
            GD.Print("[PlayerApiClient] ResponseCode: ", responseCode);

            if (responseCode != 200)
            {
                GD.PrintErr("[PlayerApiClient] ERROR: Failed to fetch players, HTTP ", responseCode);
                
                if (body != null && body.Length > 0)
                {
                    string errorBody = Encoding.UTF8.GetString(body);
                    GD.PrintErr("[PlayerApiClient] Error response: ", errorBody.Substring(0, Math.Min(500, errorBody.Length)));
                    
                    if (errorBody.Contains("<html") || errorBody.Contains("<body"))
                    {
                        GD.PrintErr("[PlayerApiClient] WARNING: Response appears to be HTML, authentication may have failed");
                        EmitSignal("load_failed", "Authentication failed: API returned HTML instead of JSON");
                    }
                    else
                    {
                        EmitSignal("load_failed", $"Failed to fetch players: HTTP {responseCode}");
                    }
                }
                else
                {
                    EmitSignal("load_failed", $"Failed to fetch players: HTTP {responseCode}, empty response");
                }
                
                _state = RequestState.Idle;
                return;
            }

            GD.Print("[PlayerApiClient] ✓ Players data received!");

            try
            {
                string jsonString = Encoding.UTF8.GetString(body);
                GD.Print("[PlayerApiClient] Players JSON length: ", jsonString.Length);
                
                if (jsonString.Length == 0)
                {
                    GD.PrintErr("[PlayerApiClient] ERROR: Empty JSON response body");
                    EmitSignal("load_failed", "Empty JSON response body");
                    _state = RequestState.Idle;
                    return;
                }
                
                if (jsonString.Length > 0)
                {
                    GD.Print("[PlayerApiClient] First 500 chars of JSON: ", jsonString.Substring(0, Math.Min(500, jsonString.Length)));
                }

                var json = Json.ParseString(jsonString);
                GD.Print("[PlayerApiClient] JSON parsed successfully, variant type: ", json.VariantType);

                if (json.VariantType == Variant.Type.Nil)
                {
                    GD.PrintErr("[PlayerApiClient] ERROR: JSON parsing returned Nil - invalid JSON or empty response");
                    GD.PrintErr("[PlayerApiClient] Raw response: ", jsonString.Substring(0, Math.Min(500, jsonString.Length)));
                    
                    if (jsonString.Contains("<html") || jsonString.Contains("<body"))
                    {
                        GD.PrintErr("[PlayerApiClient] WARNING: Response appears to be HTML - authentication may have failed");
                        EmitSignal("load_failed", "Authentication failed: API returned HTML instead of JSON");
                    }
                    else
                    {
                        EmitSignal("load_failed", "Failed to parse JSON response: returned Nil");
                    }
                    _state = RequestState.Idle;
                    return;
                }

                if (json.VariantType == Variant.Type.Array)
                {
                    GD.Print("[PlayerApiClient] API returned Array instead of Dictionary, wrapping...");
                    _playersData = new Godot.Collections.Dictionary();
                    _playersData["players"] = json.AsGodotArray();
                    GD.Print("[PlayerApiClient] Number of players: ", ((Godot.Collections.Array)_playersData["players"]).Count);
                }
                else if (json.VariantType == Variant.Type.Dictionary)
                {
                    _playersData = json.AsGodotDictionary();
                    GD.Print("[PlayerApiClient] Players data keys: ", string.Join(", ", _playersData.Keys));
                    
                    if (_playersData.ContainsKey("players"))
                    {
                        var players = _playersData["players"];
                        GD.Print("[PlayerApiClient] Players array type: ", players.VariantType);
                        
                        if (players.VariantType == Variant.Type.Array)
                        {
                            GD.Print("[PlayerApiClient] Number of players: ", ((Godot.Collections.Array)players).Count);
                        }
                    }
                }
                else
                {
                    GD.PrintErr("[PlayerApiClient] ERROR: Invalid players JSON response - expected Dictionary or Array, got ", json.VariantType);
                    EmitSignal("load_failed", $"Invalid players JSON response: expected Dictionary or Array, got {json.VariantType}");
                    _state = RequestState.Idle;
                    return;
                }

                GD.Print("[PlayerApiClient] Players data parsed. Team info (operator / roguelike /");
                GD.Print("[PlayerApiClient] squad / team_photo / final_score ...) is already embedded in each player");
                GD.Print("[PlayerApiClient] object, so we skip the redundant /api/teams request (性能优化：省去一次串行网络往返).");

                GD.Print("[PlayerApiClient] ✓ Emitting players_loaded");
                GD.Print("[PlayerApiClient] Total data keys: ", string.Join(", ", _playersData.Keys));

                EmitSignal("players_loaded", _playersData);

                _state = RequestState.Idle;
            }
            catch (Exception e)
            {
                GD.PrintErr("[PlayerApiClient] ERROR: Exception in HandlePlayersResponse: ", e.Message);
                EmitSignal("load_failed", $"Exception: {e.Message}");
                _state = RequestState.Idle;
            }
        }

    }
}
