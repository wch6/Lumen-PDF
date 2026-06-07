param(
  [Parameter(Mandatory = $true)]
  [string]$FlutterAssetsDir
)

$ErrorActionPreference = 'Stop'

function Read-Size {
  param(
    [byte[]]$Bytes,
    [ref]$Offset
  )

  $first = [int]$Bytes[$Offset.Value]
  $Offset.Value += 1
  if ($first -lt 254) {
    return $first
  }
  if ($first -eq 254) {
    $value = [BitConverter]::ToUInt16($Bytes, $Offset.Value)
    $Offset.Value += 2
    return [int]$value
  }
  $wideValue = [BitConverter]::ToUInt32($Bytes, $Offset.Value)
  $Offset.Value += 4
  return [int]$wideValue
}

function Read-Value {
  param(
    [byte[]]$Bytes,
    [ref]$Offset
  )

  $tag = [int]$Bytes[$Offset.Value]
  $Offset.Value += 1
  switch ($tag) {
    7 {
      $length = Read-Size -Bytes $Bytes -Offset $Offset
      $value = [Text.Encoding]::UTF8.GetString($Bytes, $Offset.Value, $length)
      $Offset.Value += $length
      return [pscustomobject]@{ Kind = 'String'; Value = $value }
    }
    12 {
      $length = Read-Size -Bytes $Bytes -Offset $Offset
      $items = [Collections.Generic.List[object]]::new()
      for ($i = 0; $i -lt $length; $i += 1) {
        $items.Add((Read-Value -Bytes $Bytes -Offset $Offset))
      }
      return [pscustomobject]@{ Kind = 'List'; Value = $items }
    }
    13 {
      $length = Read-Size -Bytes $Bytes -Offset $Offset
      $pairs = [Collections.Generic.List[object]]::new()
      for ($i = 0; $i -lt $length; $i += 1) {
        $key = Read-Value -Bytes $Bytes -Offset $Offset
        $value = Read-Value -Bytes $Bytes -Offset $Offset
        $pairs.Add([pscustomobject]@{ Key = $key; Value = $value })
      }
      return [pscustomobject]@{ Kind = 'Map'; Value = $pairs }
    }
    default {
      throw "Unsupported AssetManifest.bin value tag: $tag"
    }
  }
}

function Rename-Icon-Asset-Keys {
  param([object]$Node)

  switch ($Node.Kind) {
    'String' {
      if ($Node.Value.StartsWith('assets/icons/', [StringComparison]::Ordinal)) {
        $Node.Value = 'icons/' + $Node.Value.Substring('assets/icons/'.Length)
      }
    }
    'List' {
      foreach ($item in $Node.Value) {
        Rename-Icon-Asset-Keys -Node $item
      }
    }
    'Map' {
      foreach ($pair in $Node.Value) {
        Rename-Icon-Asset-Keys -Node $pair.Key
        Rename-Icon-Asset-Keys -Node $pair.Value
      }
    }
  }
}

function Write-Size {
  param(
    [Collections.Generic.List[byte]]$Output,
    [int]$Size
  )

  if ($Size -lt 254) {
    $Output.Add([byte]$Size)
    return
  }
  if ($Size -le 0xffff) {
    $Output.Add([byte]254)
    foreach ($byte in [BitConverter]::GetBytes([uint16]$Size)) {
      $Output.Add($byte)
    }
    return
  }
  $Output.Add([byte]255)
  foreach ($byte in [BitConverter]::GetBytes([uint32]$Size)) {
    $Output.Add($byte)
  }
}

function Write-Value {
  param(
    [Collections.Generic.List[byte]]$Output,
    [object]$Node
  )

  switch ($Node.Kind) {
    'String' {
      $bytes = [Text.Encoding]::UTF8.GetBytes($Node.Value)
      $Output.Add([byte]7)
      Write-Size -Output $Output -Size $bytes.Length
      foreach ($byte in $bytes) {
        $Output.Add($byte)
      }
    }
    'List' {
      $Output.Add([byte]12)
      Write-Size -Output $Output -Size $Node.Value.Count
      foreach ($item in $Node.Value) {
        Write-Value -Output $Output -Node $item
      }
    }
    'Map' {
      $Output.Add([byte]13)
      Write-Size -Output $Output -Size $Node.Value.Count
      foreach ($pair in $Node.Value) {
        Write-Value -Output $Output -Node $pair.Key
        Write-Value -Output $Output -Node $pair.Value
      }
    }
    default {
      throw "Unsupported node kind: $($Node.Kind)"
    }
  }
}

$iconsSource = Join-Path $FlutterAssetsDir 'assets\icons'
$iconsTarget = Join-Path $FlutterAssetsDir 'icons'
if (Test-Path -LiteralPath $iconsSource) {
  if (Test-Path -LiteralPath $iconsTarget) {
    Remove-Item -LiteralPath $iconsTarget -Recurse -Force
  }
  Move-Item -LiteralPath $iconsSource -Destination $iconsTarget
}

$assetsDir = Join-Path $FlutterAssetsDir 'assets'
if (Test-Path -LiteralPath $assetsDir) {
  if ((Get-ChildItem -LiteralPath $assetsDir -Force | Measure-Object).Count -eq 0) {
    Remove-Item -LiteralPath $assetsDir -Force
  }
}

$manifest = Join-Path $FlutterAssetsDir 'AssetManifest.bin'
if (Test-Path -LiteralPath $manifest) {
  $bytes = [IO.File]::ReadAllBytes($manifest)
  $offset = 0
  $node = Read-Value -Bytes $bytes -Offset ([ref]$offset)
  Rename-Icon-Asset-Keys -Node $node
  $output = [Collections.Generic.List[byte]]::new()
  Write-Value -Output $output -Node $node
  [IO.File]::WriteAllBytes($manifest, $output.ToArray())
}
