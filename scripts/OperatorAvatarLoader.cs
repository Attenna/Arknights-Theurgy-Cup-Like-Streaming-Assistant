using System;
using System.Security.Cryptography;
using System.Text;

namespace PlayerStatistics
{
    /// <summary>
    /// PRTS Wiki (prts.wiki) 干员头像 URL 构造工具。
    /// PRTS Wiki 基于 MediaWiki，文件按 UTF-8 文件名 MD5 哈希分层存储。
    /// 路径模式：{base}/{hash[0]}/{hash[0..2]}/{url_encoded_filename}
    /// 例如：头像_机械师.png → https://media.prts.wiki/5/53/%E5%A4%B4%E5%83%8F_%E6%9C%BA%E6%A2%B0%E5%B8%88.png
    /// </summary>
    public static class OperatorAvatarLoader
    {
        private const string PrtsMediaBase = "https://media.prts.wiki";

        /// <summary>
        /// 根据干员名称构造 PRTS Wiki 头像 URL。
        /// </summary>
        /// <param name="operatorName">干员中文名（来自选手数据 operator 字段）</param>
        /// <returns>完整的 PNG 头像 URL；若 operatorName 为空则返回空字符串</returns>
        public static string GetAvatarUrl(string operatorName)
        {
            if (string.IsNullOrEmpty(operatorName))
                return "";

            string filename = $"头像_{operatorName}.png";
            byte[] filenameBytes = Encoding.UTF8.GetBytes(filename);

            string hashHex;
            using (var md5 = MD5.Create())
            {
                byte[] hashBytes = md5.ComputeHash(filenameBytes);
                hashHex = BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant();
            }

            string dir1 = hashHex.Substring(0, 1);
            string dir2 = hashHex.Substring(0, 2);
            string encodedFilename = Uri.EscapeDataString(filename);

            return $"{PrtsMediaBase}/{dir1}/{dir2}/{encodedFilename}";
        }
    }
}
