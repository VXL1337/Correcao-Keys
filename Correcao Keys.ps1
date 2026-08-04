$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ZipUrl = "https://pandorakeys.com/admin/Corre%C3%A7%C3%A3o.zip"
$NomePasta = "opensteamtool"

$PastaTemporaria = Join-Path $env:TEMP "SteamFix"
$ArquivoZip = Join-Path $PastaTemporaria "correcao.zip"
$PastaExtraida = Join-Path $PastaTemporaria "extraido"

function Mostrar-Etapa {
    param(
        [string]$Mensagem,
        [int]$Porcentagem
    )

    Write-Progress `
        -Activity "Atualizando a Steam" `
        -Status $Mensagem `
        -PercentComplete $Porcentagem

    Write-Host "  $Mensagem" -ForegroundColor Cyan
}

Clear-Host

$Host.UI.RawUI.WindowTitle = "Atualização da Steam"

Write-Host ""
Write-Host "  =======================================" -ForegroundColor DarkMagenta
Write-Host "          ATUALIZACAO DA STEAM" -ForegroundColor Magenta
Write-Host "  =======================================" -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "  Aguarde enquanto preparamos tudo..." -ForegroundColor Gray
Write-Host ""

try {
    Mostrar-Etapa "Verificando a instalacao..." 10

    $PossiveisCaminhos = @()

    $RegistroUsuario = Get-ItemProperty `
        -Path "HKCU:\Software\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($RegistroUsuario.SteamPath) {
        $PossiveisCaminhos += $RegistroUsuario.SteamPath
    }

    $Registro64 = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($Registro64.InstallPath) {
        $PossiveisCaminhos += $Registro64.InstallPath
    }

    $Registro32 = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($Registro32.InstallPath) {
        $PossiveisCaminhos += $Registro32.InstallPath
    }

    if (${env:ProgramFiles(x86)}) {
        $PossiveisCaminhos += "${env:ProgramFiles(x86)}\Steam"
    }

    if ($env:ProgramFiles) {
        $PossiveisCaminhos += "$env:ProgramFiles\Steam"
    }

    if ($env:LOCALAPPDATA) {
        $PossiveisCaminhos += "$env:LOCALAPPDATA\Steam"
    }

    $SteamPath = $PossiveisCaminhos |
        Where-Object {
            $_ -and (Test-Path (Join-Path $_ "steam.exe"))
        } |
        Select-Object -First 1

    if (-not $SteamPath) {
        throw "Steam não encontrada."
    }

    Mostrar-Etapa "Preparando a atualizacao..." 25

    Get-Process `
        -Name "steam", "steamwebhelper", "GameOverlayUI" `
        -ErrorAction SilentlyContinue |
        Stop-Process `
            -Force `
            -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2

    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    New-Item `
        -ItemType Directory `
        -Path $PastaTemporaria `
        -Force |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Path $PastaExtraida `
        -Force |
        Out-Null

    Mostrar-Etapa "Obtendo os dados necessarios..." 45

    Invoke-WebRequest `
        -Uri $ZipUrl `
        -OutFile $ArquivoZip `
        -UseBasicParsing

    if (-not (Test-Path $ArquivoZip)) {
        throw "Falha no download."
    }

    Mostrar-Etapa "Aplicando a correcao..." 65

    Expand-Archive `
        -Path $ArquivoZip `
        -DestinationPath $PastaExtraida `
        -Force

    $PastaEncontrada = Get-ChildItem `
        -Path $PastaExtraida `
        -Recurse `
        -Directory `
        -Force |
        Where-Object {
            $_.Name -ieq $NomePasta
        } |
        Select-Object -First 1

    if (-not $PastaEncontrada) {
        throw "Conteúdo inválido."
    }

    $Destino = Join-Path $SteamPath $NomePasta

    if (Test-Path $Destino) {
        Remove-Item `
            -Path $Destino `
            -Recurse `
            -Force
    }

    Copy-Item `
        -LiteralPath $PastaEncontrada.FullName `
        -Destination $Destino `
        -Recurse `
        -Force

    if (-not (Test-Path $Destino)) {
        throw "Falha na instalação."
    }

    Mostrar-Etapa "Finalizando..." 90

    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Write-Progress `
        -Activity "Atualizando a Steam" `
        -Completed

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" -ForegroundColor DarkGreen
    Write-Host "          ATUALIZACAO CONCLUIDA" -ForegroundColor Green
    Write-Host "  =======================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Tudo pronto! A Steam sera iniciada." -ForegroundColor White
    Write-Host ""

    Start-Sleep -Seconds 2

    $SteamExe = Join-Path $SteamPath "steam.exe"

    if (Test-Path $SteamExe) {
        Start-Process $SteamExe
    }
}
catch {
    Write-Progress `
        -Activity "Atualizando a Steam" `
        -Completed

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" -ForegroundColor DarkRed
    Write-Host "       NAO FOI POSSIVEL CONCLUIR" -ForegroundColor Red
    Write-Host "  =======================================" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "  Abra o PowerShell como administrador" -ForegroundColor Yellow
    Write-Host "  e tente executar novamente." -ForegroundColor Yellow
    Write-Host ""
}
finally {
    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
