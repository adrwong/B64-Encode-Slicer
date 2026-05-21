param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$InputDir,

  [Parameter(Position = 1)]
  [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

try {
  $InputDir = (Resolve-Path -LiteralPath $InputDir).Path
} catch {
  Write-Error ("Error: '{0}' is not a valid directory." -f $InputDir)
  exit 1
}

if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
  Write-Error ("Error: '{0}' is not a directory." -f $InputDir)
  exit 1
}

$chunkSize = 1024 * 1024
$leaf = Split-Path -Leaf $InputDir
$parent = Split-Path -Parent $InputDir
$archiveName = "$leaf.tar"

if (-not $OutputDir) {
  $OutputDir = "$InputDir.parts"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
  $tmpTar = Join-Path $tmpDir $archiveName
  & tar -cf $tmpTar -C $parent $leaf | Out-Null

  $rawBytes = [System.IO.File]::ReadAllBytes($tmpTar)
  $base64 = [System.Convert]::ToBase64String($rawBytes)
  $encodedBytes = [System.Text.Encoding]::ASCII.GetBytes($base64)

  $totalChunks = [int][Math]::Ceiling($encodedBytes.Length / [double]$chunkSize)
  if ($totalChunks -lt 1) { $totalChunks = 1 }
  $pad = $totalChunks.ToString().Length

  $written = 0
  for ($i = 0; $i -lt $totalChunks; $i++) {
    $start = $i * $chunkSize
    $len = [Math]::Min($chunkSize, $encodedBytes.Length - $start)
    $chunk = New-Object byte[] $len
    [Array]::Copy($encodedBytes, $start, $chunk, 0, $len)

    $partName = "{0}.part{1}.txt" -f $archiveName, (($i + 1).ToString().PadLeft($pad, '0'))
    $outFile = Join-Path $OutputDir $partName
    [System.IO.File]::WriteAllBytes($outFile, $chunk)
    Write-Output ("  Written: {0}" -f $outFile)
    $written++
  }

  Write-Output ("Done. {0} chunk(s) written to '{1}'." -f $written, $OutputDir)
} finally {
  if (Test-Path -LiteralPath $tmpDir) {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
