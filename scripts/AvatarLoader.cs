using Godot;
using System;
using System.Collections.Generic;
using System.IO;

namespace PlayerStatistics
{
    public partial class AvatarLoader : Node
    {
        [Export] public string CookieHeader = "";
        [Export] public string LocalAvatarPath = "user://cache/avatars/";

        [Signal]
        public delegate void AvatarLoadedEventHandler(int playerId, Texture2D texture);

        [Signal]
        public delegate void AvatarLoadFailedEventHandler(int playerId, string error);

        private Dictionary<int, Texture2D> _cache = new Dictionary<int, Texture2D>();
        // Generic URL cache for any image (team logos, banners, etc.) that is not keyed by player id.
        private Dictionary<string, Texture2D> _urlCache = new Dictionary<string, Texture2D>();
        private Dictionary<int, HttpRequest> _activeRequests = new Dictionary<int, HttpRequest>();

        public override void _Ready()
        {
            CreateAvatarDirectory();
        }

        private void CreateAvatarDirectory()
        {
            string path = ProjectSettings.GlobalizePath(LocalAvatarPath);
            if (!Directory.Exists(path))
            {
                Directory.CreateDirectory(path);
                GD.Print("[AvatarLoader] Created avatar directory: ", path);
            }
        }

        public Texture2D GetCachedAvatar(int playerId)
        {
            _cache.TryGetValue(playerId, out Texture2D texture);
            return texture;
        }

        // Reads an already-downloaded avatar from the local cache (works even without network/cookie).
        // Useful for standalone stream scenes that share the same user:// cache as the main app.
        public Texture2D GetLocalAvatar(int playerId)
        {
            if (_cache.TryGetValue(playerId, out Texture2D cached))
                return cached;
            return LoadAvatarFromLocal(playerId);
        }

        // Generic image download keyed by URL (team logos, banners, etc.). Cached in memory for the session.
        public void LoadImage(string url, Action<Texture2D> onLoaded, Action<string> onFailed = null)
        {
            if (string.IsNullOrEmpty(url))
            {
                onFailed?.Invoke("Empty URL");
                return;
            }

            if (_urlCache.TryGetValue(url, out Texture2D cached))
            {
                onLoaded?.Invoke(cached);
                return;
            }

            var httpRequest = new HttpRequest();
            httpRequest.Timeout = 10;
            AddChild(httpRequest);

            string[] headers = { "Accept: image/*" };
            if (!string.IsNullOrEmpty(CookieHeader))
            {
                Array.Resize(ref headers, headers.Length + 1);
                headers[headers.Length - 1] = "Cookie: " + CookieHeader;
            }

            Error err = httpRequest.Request(url, headers);
            if (err != Error.Ok)
            {
                GD.PrintErr("[AvatarLoader] Failed to start image request: ", err);
                onFailed?.Invoke($"Request failed: {err}");
                httpRequest.QueueFree();
                return;
            }

            httpRequest.RequestCompleted += (long result, long responseCode, string[] responseHeaders, byte[] body) =>
            {
                if (result != (long)HttpRequest.Result.Success)
                {
                    GD.PrintErr("[AvatarLoader] Image request failed: ", (HttpRequest.Result)result, " (HTTP ", responseCode, ", URL: ", url, ")");
                    onFailed?.Invoke($"HTTP {responseCode}");
                    httpRequest.QueueFree();
                    return;
                }
                if (responseCode != 200)
                {
                    GD.PrintErr("[AvatarLoader] Image load failed: HTTP ", responseCode, " (URL: ", url, ")");
                    onFailed?.Invoke($"HTTP {responseCode}");
                    httpRequest.QueueFree();
                    return;
                }

                var decode = TryDecodeImage(body, out Image image);
                if (decode == DecodeResult.UnsupportedGif)
                {
                    GD.PrintErr("[AvatarLoader] Image is a GIF, which Godot cannot decode natively; skipping (URL: ", url, ")");
                    onFailed?.Invoke("GIF not supported");
                    httpRequest.QueueFree();
                    return;
                }
                if (decode != DecodeResult.Ok || image == null)
                {
                    GD.PrintErr("[AvatarLoader] Failed to decode image (URL: ", url, ")");
                    onFailed?.Invoke("Image decode failed");
                    httpRequest.QueueFree();
                    return;
                }

                var texture = ImageTexture.CreateFromImage(image);
                _urlCache[url] = texture;
                GD.Print("[AvatarLoader] Image loaded from URL (", body.Length, " bytes)");
                onLoaded?.Invoke(texture);

                httpRequest.QueueFree();
            };
        }

        private enum DecodeResult { Ok, UnsupportedFormat, UnsupportedGif }

        // 解码下载到的图片字节流为 Godot Image。
        // 支持 PNG / JPG / WebP；对于 GIF，提取首帧（静态图）用于显示与缓存，
        // 因为 Godot 原生 Image 不支持动图，而头像/队徽只需要第一帧即可。
        private DecodeResult TryDecodeImage(byte[] body, out Image image)
        {
            image = null;
            if (body == null || body.Length < 6)
                return DecodeResult.UnsupportedFormat;

            // GIF 文件头: "GIF87a" / "GIF89a"
            bool isGif = body[0] == (byte)'G' && body[1] == (byte)'I' && body[2] == (byte)'F' &&
                         body[3] == (byte)'8' && (body[4] == (byte)'7' || body[4] == (byte)'9') && body[5] == (byte)'a';

            if (isGif)
            {
                // 提取首帧作为静态图（后续按 PNG 缓存显示）
                var gifImage = DecodeGifFirstFrame(body);
                if (gifImage != null)
                {
                    image = gifImage;
                    GD.Print("[AvatarLoader] GIF detected; using first frame as static image.");
                    return DecodeResult.Ok;
                }
                return DecodeResult.UnsupportedGif;
            }

            var img = new Image();
            Error err = img.LoadPngFromBuffer(body);
            if (err != Error.Ok)
                err = img.LoadJpgFromBuffer(body);
            if (err != Error.Ok)
            {
                try { err = img.LoadWebpFromBuffer(body); }
                catch { err = Error.Failed; }
            }
            if (err != Error.Ok)
                return DecodeResult.UnsupportedFormat;

            image = img;
            return DecodeResult.Ok;
        }

        // 解析 GIF 的首帧，返回 RGBA8 的 Godot.Image（静态首帧）。失败时返回 null。
        // 纯 C# 实现，无第三方依赖；支持局部/全局调色板、交错与透明色。
        private Image DecodeGifFirstFrame(byte[] data)
        {
            try
            {
                int pos = 6;
                int screenW = data[pos] | (data[pos + 1] << 8);
                int screenH = data[pos + 2] | (data[pos + 3] << 8);
                byte packed = data[pos + 4];
                pos += 7; // width(2) height(2) packed(1) bg(1) aspect(1)

                bool gctFlag = (packed & 0x80) != 0;
                byte[] gct = null;
                if (gctFlag)
                {
                    int gctSize = 1 << ((packed & 0x07) + 1);
                    gct = new byte[gctSize * 3];
                    Array.Copy(data, pos, gct, 0, gct.Length);
                    pos += gct.Length;
                }

                int transparentIndex = -1;

                while (pos < data.Length)
                {
                    int block = data[pos++];
                    if (block == 0x3B) break; // trailer

                    if (block == 0x21) // extension
                    {
                        int label = data[pos++];
                        if (label == 0xF9) // Graphic Control Extension
                        {
                            int size = data[pos];        // 应为 4
                            byte gcePacked = data[pos + 1];
                            int trans = data[pos + 4];
                            if ((gcePacked & 0x01) != 0) transparentIndex = trans;
                            pos += size;   // 跳过 size 字节
                            pos++;         // 跳过块终结符 0x00
                        }
                        else
                        {
                            // 跳过子块
                            while (pos < data.Length && data[pos] != 0)
                            {
                                int len = data[pos++];
                                pos += len;
                            }
                            if (pos < data.Length) pos++; // 终结符
                        }
                    }
                    else if (block == 0x2C) // Image Descriptor
                    {
                        int left = data[pos] | (data[pos + 1] << 8);
                        int top = data[pos + 2] | (data[pos + 3] << 8);
                        int iw = data[pos + 4] | (data[pos + 5] << 8);
                        int ih = data[pos + 6] | (data[pos + 7] << 8);
                        byte ipacked = data[pos + 8];
                        pos += 9;

                        byte[] lct = null;
                        if ((ipacked & 0x80) != 0)
                        {
                            int lctSize = 1 << ((ipacked & 0x07) + 1);
                            lct = new byte[lctSize * 3];
                            Array.Copy(data, pos, lct, 0, lct.Length);
                            pos += lct.Length;
                        }

                        int minCodeSize = data[pos++];

                        var lzw = new List<byte>();
                        while (pos < data.Length && data[pos] != 0)
                        {
                            int len = data[pos++];
                            for (int i = 0; i < len && pos < data.Length; i++)
                                lzw.Add(data[pos++]);
                        }
                        if (pos < data.Length) pos++; // 终结符

                        byte[] palette = lct ?? gct;
                        if (palette == null) return null;

                        byte[] indices = GifLzwDecode(lzw.ToArray(), minCodeSize);
                        if (indices == null) return null;

                        bool interlaced = (ipacked & 0x40) != 0;
                        return BuildGifImage(screenW, screenH, indices, palette, left, top, iw, ih, interlaced, transparentIndex);
                    }
                    else
                    {
                        break; // 未知块，停止
                    }
                }
                return null;
            }
            catch (Exception e)
            {
                GD.PrintErr("[AvatarLoader] GIF first-frame decode failed: ", e.Message);
                return null;
            }
        }

        private Image BuildGifImage(int screenW, int screenH, byte[] indices, byte[] palette,
                                    int left, int top, int iw, int ih, bool interlaced, int transparentIndex)
        {
            var rgba = new byte[screenW * screenH * 4];
            int[] rowMap = null;
            if (interlaced)
            {
                rowMap = new int[ih];
                int dst = 0;
                int[] starts = { 0, 4, 2, 1 };
                int[] steps = { 8, 8, 4, 2 };
                for (int p = 0; p < 4; p++)
                    for (int r = starts[p]; r < ih; r += steps[p])
                        rowMap[dst++] = r;
            }

            for (int y = 0; y < ih; y++)
            {
                int dstY = interlaced ? top + rowMap[y] : top + y;
                if (dstY < 0 || dstY >= screenH) continue;
                for (int x = 0; x < iw; x++)
                {
                    int dstX = left + x;
                    if (dstX < 0 || dstX >= screenW) continue;
                    int c = indices[y * iw + x];
                    int di = (dstY * screenW + dstX) * 4;
                    if (c == transparentIndex)
                    {
                        rgba[di + 3] = 0; // 透明像素
                        continue;
                    }
                    if (c * 3 + 2 >= palette.Length) continue;
                    rgba[di] = palette[c * 3];
                    rgba[di + 1] = palette[c * 3 + 1];
                    rgba[di + 2] = palette[c * 3 + 2];
                    rgba[di + 3] = 255;
                }
            }

            return Image.CreateFromData(screenW, screenH, false, Image.Format.Rgba8, rgba);
        }

        // GIF 的 LZW 解码（变长码、无 early-change）。
        private byte[] GifLzwDecode(byte[] data, int minCodeSize)
        {
            if (minCodeSize < 2 || minCodeSize > 11) return null;
            int clearCode = 1 << minCodeSize;
            int eoiCode = clearCode + 1;
            int codeWidth = minCodeSize + 1;

            var dict = new List<byte[]>();
            for (int i = 0; i < clearCode; i++)
                dict.Add(new byte[] { (byte)i });
            dict.Add(null); // clear
            dict.Add(null); // eoi

            var output = new List<byte>(data.Length * 4);

            int bitPos = 0;
            int totalBits = data.Length * 8;
            byte[] prev = null;
            bool first = true;

            while (bitPos + codeWidth <= totalBits)
            {
                int code = ReadBits(data, bitPos, codeWidth);
                bitPos += codeWidth;

                if (code == clearCode)
                {
                    dict.Clear();
                    for (int i = 0; i < clearCode; i++)
                        dict.Add(new byte[] { (byte)i });
                    dict.Add(null);
                    dict.Add(null);
                    codeWidth = minCodeSize + 1;
                    prev = null;
                    first = true;
                    continue;
                }
                if (code == eoiCode) break;

                byte[] entry;
                if (first)
                {
                    if (code < dict.Count && dict[code] != null)
                        entry = dict[code];
                    else break;
                    output.AddRange(entry);
                    prev = entry;
                    first = false;
                    continue;
                }

                if (code < dict.Count && dict[code] != null)
                    entry = dict[code];
                else if (code == dict.Count && prev != null)
                    entry = Concat(prev, prev[0]);
                else break;

                output.AddRange(entry);

                if (prev != null)
                {
                    dict.Add(Concat(prev, entry[0]));
                    if (codeWidth < 12 && dict.Count == (1 << codeWidth))
                        codeWidth++;
                }
                prev = entry;
            }

            return output.ToArray();
        }

        private int ReadBits(byte[] data, int bitPos, int count)
        {
            int value = 0;
            for (int i = 0; i < count; i++)
            {
                int byteIndex = (bitPos + i) / 8;
                int bitIndex = (bitPos + i) % 8;
                if (byteIndex >= data.Length) break;
                int bit = (data[byteIndex] >> bitIndex) & 1;
                value |= bit << i;
            }
            return value;
        }

        private byte[] Concat(byte[] a, byte b)
        {
            var r = new byte[a.Length + 1];
            Array.Copy(a, r, a.Length);
            r[a.Length] = b;
            return r;
        }

        public void LoadAvatar(int playerId, string url, Action<int, Texture2D> onLoaded, Action<int, string> onFailed = null)
        {
            if (string.IsNullOrEmpty(url))
            {
                onFailed?.Invoke(playerId, "Empty URL");
                return;
            }

            if (_cache.ContainsKey(playerId))
            {
                onLoaded?.Invoke(playerId, _cache[playerId]);
                return;
            }

            Texture2D localTexture = LoadAvatarFromLocal(playerId);
            if (localTexture != null)
            {
                _cache[playerId] = localTexture;
                GD.Print("[AvatarLoader] Loaded avatar from local for player ", playerId);
                onLoaded?.Invoke(playerId, localTexture);
                return;
            }

            if (_activeRequests.ContainsKey(playerId))
            {
                GD.Print("[AvatarLoader] Already loading avatar for player ", playerId);
                return;
            }

            var httpRequest = new HttpRequest();
            httpRequest.Timeout = 10;
            AddChild(httpRequest);

            _activeRequests[playerId] = httpRequest;

            string[] headers = { "Accept: image/*" };
            if (!string.IsNullOrEmpty(CookieHeader))
            {
                Array.Resize(ref headers, headers.Length + 1);
                headers[headers.Length - 1] = "Cookie: " + CookieHeader;
            }

            Error err = httpRequest.Request(url, headers);
            if (err != Error.Ok)
            {
                GD.PrintErr("[AvatarLoader] Failed to start request for player ", playerId, ": ", err);
                onFailed?.Invoke(playerId, $"Request failed: {err}");
                _activeRequests.Remove(playerId);
                httpRequest.QueueFree();
                return;
            }

            httpRequest.RequestCompleted += (long result, long responseCode, string[] responseHeaders, byte[] body) =>
            {
                _activeRequests.Remove(playerId);

                if (result != (long)HttpRequest.Result.Success)
                {
                    GD.PrintErr("[AvatarLoader] Avatar request failed for player ", playerId, ": ", (HttpRequest.Result)result, " (HTTP ", responseCode, ")");
                    onFailed?.Invoke(playerId, $"HTTP {responseCode}");
                    httpRequest.QueueFree();
                    return;
                }
                if (responseCode != 200)
                {
                    GD.PrintErr("[AvatarLoader] Avatar load failed for player ", playerId, ": HTTP ", responseCode);
                    onFailed?.Invoke(playerId, $"HTTP {responseCode}");
                    httpRequest.QueueFree();
                    return;
                }

                try
                {
                    var decode = TryDecodeImage(body, out Image image);
                    if (decode == DecodeResult.UnsupportedGif)
                    {
                        GD.PrintErr("[AvatarLoader] Player ", playerId, " avatar is a GIF, which Godot cannot decode natively; skipping avatar (name/team still shown).");
                        onFailed?.Invoke(playerId, "GIF not supported");
                        return;
                    }
                    if (decode != DecodeResult.Ok || image == null)
                    {
                        GD.PrintErr("[AvatarLoader] Failed to decode image for player ", playerId);
                        onFailed?.Invoke(playerId, "Image decode failed");
                        return;
                    }

                    var texture = ImageTexture.CreateFromImage(image);
                    _cache[playerId] = texture;

                    SaveAvatarToLocal(playerId, image);

                    GD.Print("[AvatarLoader] Avatar loaded for player ", playerId, " (", body.Length, " bytes)");
                    onLoaded?.Invoke(playerId, texture);
                    EmitSignal("AvatarLoaded", playerId, texture);
                }
                catch (Exception e)
                {
                    GD.PrintErr("[AvatarLoader] Exception loading avatar for player ", playerId, ": ", e.Message);
                    onFailed?.Invoke(playerId, $"Exception: {e.Message}");
                    EmitSignal("AvatarLoadFailed", playerId, $"Exception: {e.Message}");
                }

                httpRequest.QueueFree();
            };
        }

        public void ClearCache()
        {
            _cache.Clear();
            GD.Print("[AvatarLoader] Cache cleared");
        }

        public void SetCookie(string cookie)
        {
            CookieHeader = cookie;
            GD.Print("[AvatarLoader] Cookie set");
        }

        private void SaveAvatarToLocal(int playerId, Image image)
        {
            try
            {
                string path = ProjectSettings.GlobalizePath(LocalAvatarPath);
                string ext = GetImageExtension(image);
                string filePath = Path.Combine(path, $"{playerId}.{ext}");

                using var file = Godot.FileAccess.Open(filePath, Godot.FileAccess.ModeFlags.Write);
                if (ext == "png")
                {
                    file.StoreBuffer(image.SavePngToBuffer());
                }
                else
                {
                    file.StoreBuffer(image.SaveJpgToBuffer(95));
                }
                file.Close();

                GD.Print("[AvatarLoader] Saved avatar to local: ", filePath);
            }
            catch (Exception e)
            {
                GD.PrintErr("[AvatarLoader] Failed to save avatar to local for player ", playerId, ": ", e.Message);
            }
        }

        private Texture2D LoadAvatarFromLocal(int playerId)
        {
            try
            {
                string path = ProjectSettings.GlobalizePath(LocalAvatarPath);
                
                string[] extensions = { "png", "jpg", "jpeg" };
                foreach (string ext in extensions)
                {
                    string filePath = Path.Combine(path, $"{playerId}.{ext}");
                    if (Godot.FileAccess.FileExists(filePath))
                    {
                        var image = Image.LoadFromFile(filePath);
                        if (image != null && image.GetWidth() > 0)
                        {
                            return ImageTexture.CreateFromImage(image);
                        }
                    }
                }
            }
            catch (Exception e)
            {
                GD.PrintErr("[AvatarLoader] Failed to load avatar from local for player ", playerId, ": ", e.Message);
            }
            
            return null;
        }

        private string GetImageExtension(Image image)
        {
            switch (image.GetFormat())
            {
                case Image.Format.Rgba8:
                case Image.Format.Rgb8:
                case Image.Format.Rgba4444:
                case Image.Format.Rgb565:
                    return "png";
                default:
                    return "jpg";
            }
        }

        public void PreloadAllAvatars(List<PlayerData> players)
        {
            foreach (var player in players)
            {
                if (!string.IsNullOrEmpty(player.AvatarUrl))
                {
                    LoadAvatar(player.Id, player.AvatarUrl, null, null);
                }
            }
            GD.Print("[AvatarLoader] Preloading ", players.Count, " avatars");
        }
    }
}
