<#
  NBN Cloud: monta o MSI a partir do pacote portátil do Craft.

  .\gerar-msi.ps1 -SourceDir <pasta com bin\nbncloud.exe> -Version 6.0.3.12 -Out <pasta de saída>

  Usa o WiX 5 (dotnet tool, versão fixa, instalado numa pasta própria) e o Pillow para o .ico.
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

# ícone do Painel de Controle e do atalho, a partir dos PNGs da marca
$png = Join-Path $aqui '..\theme\colored\256-nbncloud-icon.png'
$ico = Join-Path $Out 'nbncloud.ico'
& $Python -c "from PIL import Image; import sys; Image.open(sys.argv[1]).save(sys.argv[2], sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])" $png $ico
if ($LASTEXITCODE -ne 0) { throw 'falha ao gerar o .ico (precisa do Pillow)' }

$msi = Join-Path $Out "NBNCloud-$Version-x64.msi"
& $wix build (Join-Path $aqui 'nbncloud.wxs') -arch x64 `
    -d "Version=$Version" -d "SourceDir=$SourceDir" -d "IconFile=$ico" `
    -o $msi | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'falha no wix build' }
Remove-Item (Join-Path $Out '*.wixpdb') -ErrorAction SilentlyContinue
Remove-Item $ico -ErrorAction SilentlyContinue
Get-Item $msi | Format-Table Name, Length
