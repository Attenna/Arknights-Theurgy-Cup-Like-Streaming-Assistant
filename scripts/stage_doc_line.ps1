# scripts/stage_doc_line.ps1
# 在工作树存在其它未提交改动时，只把「指定文档里的一行」放进 git index。
#
# 做法：从 HEAD 取干净内容 → 在 Anchor 行后插入 NewLine → 生成 blob 并 update-index；
# 同时把同一行写入工作区，避免提交后工作区看起来"删掉了这一行"。
#
# 用法：
#   .\scripts\stage_doc_line.ps1 -Path README.md `
#       -Anchor "| [AGENTS.md](AGENTS.md) | ... |" `
#       -NewLine "| [代码库导览](framework/docs/代码库导览.md) | ... |"
#   .\scripts\stage_doc_line.ps1 ... -WhatIf
#
# 约束：
# - Path 相对仓库根目录，且必须已被 git 跟踪；
# - Anchor 必须在 HEAD 版本中恰好出现一次（整行匹配）；
# - NewLine 不得已存在于 HEAD 或工作区，避免重复插入；
# - 只改 index 与目标文件，不碰其它未提交改动。

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Anchor,
    [Parameter(Mandatory = $true)][string]$NewLine
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-GitBytes {
    param([string]$RepoRoot, [string]$GitArgs)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $GitArgs
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    $p.StandardOutput.BaseStream.CopyTo($ms)
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) {
        throw "git 失败（$($p.ExitCode)）：$stderr"
    }
    return $ms.ToArray()
}

$root = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
    throw '当前目录不在 git 仓库内'
}
$relPath = $Path.Replace('\', '/').TrimStart('/')
$fullPath = Join-Path $root $relPath
if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    throw "文件不存在: $fullPath"
}
& git -C $root ls-files --error-unmatch -- $relPath *> $null
if ($LASTEXITCODE -ne 0) {
    throw "文件未被 git 跟踪: $relPath"
}

$headText = [System.Text.Encoding]::UTF8.GetString((Get-GitBytes $root ('-C "' + $root + '" show "HEAD:' + $relPath + '"')))
$headText = $headText.Replace("`r`n", "`n")
$linePattern = "(?m)^" + [regex]::Escape($Anchor) + '$'
$anchorMatches = [regex]::Matches($headText, $linePattern)
if ($anchorMatches.Count -ne 1) {
    throw "Anchor 在 HEAD 版本中应恰好出现一次，实际 $($anchorMatches.Count) 次: $Anchor"
}
$newLinePattern = "(?m)^" + [regex]::Escape($NewLine) + '$'
if ([regex]::IsMatch($headText, $newLinePattern)) {
    throw "HEAD 版本已包含要插入的行: $NewLine"
}

# 索引内容：LF，插到 Anchor 行之后
$insertAt = $anchorMatches[0].Index + $anchorMatches[0].Length
if ($insertAt -lt $headText.Length -and $headText[$insertAt] -eq "`n") {
    $insertAt++
}
$indexText = $headText.Insert($insertAt, $NewLine + "`n")

# 工作区内容：保留原行尾（CRLF / LF）与是否以换行结尾
$workText = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
$eol = if ($workText.Contains("`r`n")) { "`r`n" } else { "`n" }
if ([regex]::IsMatch($workText, "(?m)^" + [regex]::Escape($NewLine) + "\r?$")) {
    throw "工作区已包含要插入的行: $NewLine"
}
$workPattern = "(?m)^" + [regex]::Escape($Anchor) + "\r?$"
$workMatches = [regex]::Matches($workText, $workPattern)
if ($workMatches.Count -ne 1) {
    throw "Anchor 在工作区中应恰好出现一次，实际 $($workMatches.Count) 次: $Anchor"
}
$workInsertAt = $workMatches[0].Index + $workMatches[0].Length
if ($workInsertAt -lt $workText.Length -and $workText[$workInsertAt] -eq "`r" -and $workInsertAt + 1 -lt $workText.Length -and $workText[$workInsertAt + 1] -eq "`n") {
    $workInsertAt += 2
} elseif ($workInsertAt -lt $workText.Length -and $workText[$workInsertAt] -eq "`n") {
    $workInsertAt++
}
$newWorkText = $workText.Insert($workInsertAt, $NewLine + $eol)

if (-not $PSCmdlet.ShouldProcess($relPath, "暂存一行：$NewLine")) {
    return
}

$tmp = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tmp, $indexText, $utf8)
    $hash = (& git -C $root hash-object -w --path $relPath $tmp | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $hash.Length -eq 0) {
        throw 'git hash-object 失败'
    }
    & git -C $root update-index --cacheinfo 100644 $hash $relPath
    if ($LASTEXITCODE -ne 0) {
        throw 'git update-index 失败'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

[System.IO.File]::WriteAllText($fullPath, $newWorkText, $utf8)

Write-Host "已暂存: $relPath"
Write-Host "  锚点: $Anchor"
Write-Host "  新增: $NewLine"
Write-Host ''
& git -C $root diff --cached -- $relPath
