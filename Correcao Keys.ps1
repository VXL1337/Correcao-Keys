$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ZipUrl = "https://pandorakeys.com/admin/Correcao.zip"
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

function Encontrar-Steam {
    $Caminhos = @()

    $RegistroUsuario = Get-ItemProperty `
        -Path "HKCU:\Software\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($RegistroUsuario.SteamPath) {
        $Caminhos += $RegistroUsuario.SteamPath
    }

    $Registro64 = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($Registro64.InstallPath) {
        $Caminhos += $Registro64.InstallPath
    }

    $Registro32 = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($Registro32.InstallPath) {
        $Caminhos += $Registro32.InstallPath
    }

    if (${env:ProgramFiles(x86)}) {
        $Caminhos += "${env:ProgramFiles(x86)}\Steam"
    }

    if ($env:ProgramFiles) {
        $Caminhos += "$env:ProgramFiles\Steam"
    }

    if ($env:LOCALAPPDATA) {
        $Caminhos += "$env:LOCALAPPDATA\Steam"
    }

    return $Caminhos |
        Select-Object -Unique |
        Where-Object {
            $_ -and (Test-Path (Join-Path $_ "steam.exe"))
        } |
        Select-Object -First 1
}

function Encerrar-Steam {
    param(
        [string]$SteamPath
    )

    $SteamExe = Join-Path $SteamPath "steam.exe"

    # Solicita primeiro o encerramento normal
    if (Test-Path $SteamExe) {
        Start-Process `
            -FilePath $SteamExe `
            -ArgumentList "-shutdown" `
            -WindowStyle Hidden `
            -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 3

    # Interrompe o servico da Steam
    $ServicoSteam = Get-Service `
        -DisplayName "Steam Client Service" `
        -ErrorAction SilentlyContinue

    if ($ServicoSteam -and $ServicoSteam.Status -ne "Stopped") {
        $ServicoSteam |
            Stop-Service `
                -Force `
                -ErrorAction SilentlyContinue
    }

    $ProcessosSteam = @(
        "steam",
        "steamwebhelper",
        "GameOverlayUI",
        "steamservice",
        "steamerrorreporter",
        "steamerrorreporter64",
        "steam_monitor",
        "steamxboxutil",
        "steamxboxutil64"
    )

    $TaskKill = Join-Path $env:SystemRoot "System32\taskkill.exe"

    # Mata tambem os processos filhos
    foreach ($Processo in $ProcessosSteam) {
        if (Test-Path $TaskKill) {
            & $TaskKill `
                /F `
                /T `
                /IM "$Processo.exe" `
                2>$null |
                Out-Null
        }
    }

    # Confirma por ate 15 segundos que tudo fechou
    $Limite = (Get-Date).AddSeconds(15)

    do {
        $Restantes = Get-Process `
            -Name $ProcessosSteam `
            -ErrorAction SilentlyContinue

        if (-not $Restantes) {
            break
        }

        $Restantes |
            Stop-Process `
                -Force `
                -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 1
    }
    while ((Get-Date) -lt $Limite)

    $Restantes = Get-Process `
        -Name $ProcessosSteam `
        -ErrorAction SilentlyContinue

    if ($Restantes) {
        throw "Nao foi possivel reiniciar completamente a Steam."
    }

    Start-Sleep -Seconds 2
}

Clear-Host

try {
    $Host.UI.RawUI.WindowTitle = "Atualizacao da Steam"
}
catch {}

Write-Host ""
Write-Host "  =======================================" -ForegroundColor DarkMagenta
Write-Host "          ATUALIZACAO DA STEAM" -ForegroundColor Magenta
Write-Host "  =======================================" -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "  Aguarde enquanto preparamos tudo..." -ForegroundColor Gray
Write-Host ""

try {
    Mostrar-Etapa "Verificando a instalacao..." 10

    $SteamPath = Encontrar-Steam

    if (-not $SteamPath) {
        throw "Steam nao encontrada."
    }

    Mostrar-Etapa "Reiniciando completamente..." 25

    Encerrar-Steam -SteamPath $SteamPath

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

    if (
        -not (Test-Path $ArquivoZip) -or
        (Get-Item $ArquivoZip).Length -eq 0
    ) {
        throw "Falha ao obter os dados."
    }

    Mostrar-Etapa "Aplicando a atualizacao..." 65

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
        throw "Conteudo invalido."
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
        -Destination $SteamPath `
        -Recurse `
        -Force

    if (-not (Test-Path $Destino)) {
        throw "Falha ao aplicar a atualizacao."
    }

    Mostrar-Etapa "Finalizando..." 90

    Remove-Item `
        -Path $PastaTemporaria `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Write-Progress `
        -Activity "Atualizando a Steam" `
        -Completed

    # Inicia novamente o servico, quando existente
    $ServicoSteam = Get-Service `
        -DisplayName "Steam Client Service" `
        -ErrorAction SilentlyContinue

    if ($ServicoSteam) {
        $ServicoSteam |
            Start-Service `
                -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 2

    $SteamExe = Join-Path $SteamPath "steam.exe"

    if (Test-Path $SteamExe) {
        Start-Process -FilePath $SteamExe
    }

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" -ForegroundColor DarkGreen
    Write-Host "          ATUALIZACAO CONCLUIDA" -ForegroundColor Green
    Write-Host "  =======================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Tudo pronto! A Steam foi reiniciada." -ForegroundColor White
    Write-Host ""
    Write-Host "  Fechando automaticamente em 3 segundos..." -ForegroundColor DarkGray
    Write-Host ""

    Start-Sleep -Seconds 3
    exit 0
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
    Write-Host "  Execute o PowerShell como administrador" -ForegroundColor Yellow
    Write-Host "  e tente novamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Fechando em 5 segundos..." -ForegroundColor DarkGray

    Start-Sleep -Seconds 5
    exit 1
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
