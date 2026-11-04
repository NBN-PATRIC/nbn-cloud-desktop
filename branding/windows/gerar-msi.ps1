<#
  NBN Cloud: monta o MSI a partir do pacote portátil do Craft.

  .\gerar-msi.ps1 -SourceDir <pasta com bin\nbncloud.exe> -Version 6.0.3.12 -Out <pasta de saída>

  Usa o WiX 5 (dotnet tool e extensões UI e Util, versão fixa, numa pasta própria) e o Pillow para o
  ícone, a arte das telas e a licença (arte_instalador.py).
  Roda no CI (nbn-windows.yml) e em qualquer PC com o .NET SDK e Python.
#>
param(
    [Parameter(Mandatory)] [string] $SourceDir,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Out,
    [string] $WixVersion = '5.0.2',
    [string] $Python = 'python'
)
$ErrorActionPreference = 'Stop'
$aqui = $PSScriptRoot
$SourceDir = (Resolve-Path $SourceDir).Path
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path

if (-not (Test-Path (Join-Path $SourceDir 'bin\nbncloud.exe'))) {
    throw "Não achei bin\nbncloud.exe em $SourceDir"
}

# WiX fixo numa pasta local de ferramentas (não mexe no PATH global)
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$ferramentas = Join-Path $tmp "nbncloud-wix-$WixVersion"
$wix = Join-Path $ferramentas 'wix.exe'
if (-not (Test-Path $wix)) {
    dotnet tool install wix --version $WixVersion --tool-path $ferramentas | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'falha ao instalar o WiX' }
}

# extensões das telas (UI) e da ação "abrir no fim" (Util), no cache local da pasta de ferramentas
$extensoes = 'WixToolset.UI.wixext', 'WixToolset.Util.wixext'
Push-Location $ferramentas
try {
    foreach ($e in $extensoes) {
        if (-not (Test-Path (Join-Path $ferramentas ".wix\extensions\$e\$WixVersion"))) {
            & $wix extension add "$e/$WixVersion" | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "falha ao instalar a extensão $e" }
        }
    }

    # ícone, faixas das telas e licença, a partir dos PNGs da marca e do COPYING
    $arte = Join-Path $tmp "nbncloud-arte-$PID"
    $argsArte = @((Join-Path $aqui 'arte_instalador.py'), $arte)
    if (Test-Path (Join-Path $SourceDir 'bin\ownCloud_vfs_wincfapi.dll')) { $argsArte += '--plugin-vfs' }
    & $Python @argsArte
    if ($LASTEXITCODE -ne 0) { throw 'falha ao gerar a arte do instalador (precisa do Pillow)' }

    $msi = Join-Path $Out "NBNCloud-$Version-x64.msi"
    & $wix build (Join-Path $aqui 'nbncloud.wxs') -arch x64 -culture pt-BR `
        -ext WixToolset.UI.wixext -ext WixToolset.Util.wixext `
        -d "Version=$Version" -d "SourceDir=$SourceDir" -d "ArteDir=$arte" `
        -o $msi | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'falha no wix build' }
}
finally {
    Pop-Location
    if ($arte) { Remove-Item $arte -Recurse -Force -ErrorAction SilentlyContinue }
}
Remove-Item (Join-Path $Out '*.wixpdb') -ErrorAction SilentlyContinue
Get-Item $msi | Format-Table Name, Length
