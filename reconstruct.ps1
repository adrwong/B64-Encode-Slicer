$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ChunksDir,

  [Parameter(Position = 1)]
  [string]$Output
)

try {
  $ChunksDir = (Resolve-Path -LiteralPath $ChunksDir).Path
} catch {
  Write-Error ("Error: '{0}' is not a valid directory." -f $ChunksDir)
  exit 1
}

if (-not (Test-Path -LiteralPath $ChunksDir -PathType Container)) {
  Write-Error ("Error: '{0}' is not a directory." -f $ChunksDir)
  exit 1
}

$pattern = '^(.+)\.part(\d+)\.txt$'
$candidates = Get-ChildItem -LiteralPath $ChunksDir -File |
  ForEach-Object {
    if ($_.Name -match $pattern) {
      [PSCustomObject]@{
        Base = $matches[1]
        Part = [int]$matches[2]
        Path = $_.FullName
      }
    }
  }

if (-not $candidates) {
  Write-Error ("Error: no chunk files (*.part<N>.txt) found in '{0}'." -f $ChunksDir)
  exit 1
}

$baseNames = $candidates.Base | Select-Object -Unique
if ($baseNames.Count -gt 1) {
  $joined = ($baseNames | Sort-Object) -join ', '
  Write-Error ("Error: multiple chunk sets found ({0}). Place only one set of chunks in the directory." -f $joined)
  exit 1
}

$baseName = $baseNames[0]
$parts = $candidates | Sort-Object -Property Part

if (-not $Output) {
  $Output = Join-Path -Path (Split-Path -Parent $ChunksDir) -ChildPath $baseName
}

$outputDir = Split-Path -Parent $Output
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Output ("Reassembling '{0}' from {1} chunk(s) …" -f $baseName, $parts.Count)
$builder = [System.Text.StringBuilder]::new()
foreach ($part in $parts) {
  Write-Output ("  Read: {0}" -f $part.Path)
  $null = $builder.Append((Get-Content -LiteralPath $part.Path -Raw))
}

try {
  $decodedBytes = [System.Convert]::FromBase64String($builder.ToString())
} catch {
  Write-Error ("Base64 decoding failed — the chunk files may be corrupted or incomplete. Details: {0}" -f $_.Exception.Message)
  exit 1
}

[System.IO.File]::WriteAllBytes($Output, $decodedBytes)
Write-Output ("Done. Reconstructed file written to '{0}'." -f $Output)
