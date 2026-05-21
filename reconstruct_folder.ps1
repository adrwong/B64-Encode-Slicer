param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ChunksDir,

  [Parameter(Position = 1)]
  [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

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

$baseNames = @($candidates.Base | Select-Object -Unique)
if ($baseNames.Count -gt 1) {
  $joined = ($baseNames | Sort-Object) -join ', '
  Write-Error ("Error: multiple chunk sets found ({0}). Place only one set of chunks in the directory." -f $joined)
  exit 1
}

$baseName = $baseNames[0]
$parts = $candidates | Sort-Object -Property Part

$folderName = $baseName
if ($folderName.EndsWith('.tar')) {
  $folderName = $folderName.Substring(0, $folderName.Length - 4)
}

if (-not $OutputDir) {
  $OutputDir = Join-Path -Path (Split-Path -Parent $ChunksDir) -ChildPath $folderName
}

if (Test-Path -LiteralPath $OutputDir) {
  Write-Error ("Error: output path '{0}' already exists." -f $OutputDir)
  exit 1
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
  Write-Output ("Reassembling '{0}' from {1} chunk(s) ..." -f $baseName, $parts.Count)
  $builder = [System.Text.StringBuilder]::new()
  foreach ($part in $parts) {
    Write-Output ("  Read: {0}" -f $part.Path)
    $null = $builder.Append((Get-Content -LiteralPath $part.Path -Raw))
  }

  try {
    $decodedBytes = [System.Convert]::FromBase64String($builder.ToString())
  } catch {
    Write-Error ("Base64 decoding failed - the chunk files may be corrupted or incomplete. Details: {0}" -f $_.Exception.Message)
    exit 1
  }

  $tmpTar = Join-Path $tmpDir $baseName
  [System.IO.File]::WriteAllBytes($tmpTar, $decodedBytes)

  $tmpExtract = Join-Path $tmpDir 'extract'
  New-Item -ItemType Directory -Path $tmpExtract -Force | Out-Null
  & tar -xf $tmpTar -C $tmpExtract | Out-Null

  $extractedRoot = Join-Path $tmpExtract $folderName
  if (-not (Test-Path -LiteralPath $extractedRoot -PathType Container)) {
    $roots = Get-ChildItem -LiteralPath $tmpExtract -Directory
    if ($roots.Count -eq 1) {
      $extractedRoot = $roots[0].FullName
    } else {
      $names = ($roots | Select-Object -ExpandProperty Name | Sort-Object) -join ', '
      if (-not $names) {
        $names = '(none)'
      }
      Write-Error ("Error: expected a single root folder in archive; extraction produced: {0}" -f $names)
      exit 1
    }
  }

  $parentOut = Split-Path -Parent $OutputDir
  if ($parentOut -and -not (Test-Path -LiteralPath $parentOut)) {
    New-Item -ItemType Directory -Path $parentOut -Force | Out-Null
  }

  Move-Item -LiteralPath $extractedRoot -Destination $OutputDir
  Write-Output ("Done. Reconstructed folder written to '{0}'." -f $OutputDir)
} finally {
  if (Test-Path -LiteralPath $tmpDir) {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
