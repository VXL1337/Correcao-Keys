$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Link RAW deste próprio script
$ScriptUrl = "https://raw.githubusercontent.com/VXL1337/Correcao-Keys/main/correcao-keys.ps1"

# Link direto do ZIP
$ZipUrl = "https://pandorakeys.com/admin/Correcao.zip"

# Pasta que existe dentro do ZIP
$NomePasta = "opensteamtool"

# Arquivos temporários
$PastaTemporaria = Join-Path $env:TEMP "SteamFix"
$ArquivoZip = Join-Path $PastaTemporaria "correcao.zip"
$PastaExtraida = Join-Path $PastaTemporaria "extraido"

function Testar-Administrador {
    $Identidade = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object `
        Security.Principal.WindowsPrincipal($Identidade)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Mostrar-TelaInicial {
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
}

function Mostrar-Etapa {
    param(
        [string]$Mensagem
    )

    Write-Host "  $Mensagem" -ForegroundColor Cyan
}

function Mostrar-Sucesso {
    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" -ForegroundColor DarkGreen
    Write-Host "          ATUALIZACAO CONCLUIDA" -ForegroundColor Green
    Write-Host "  =======================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Tudo pronto! A Steam esta iniciando." -ForegroundColor White
    Write-Host ""
    Write-Host "  Fechando automaticamente em 3 segundos..." -ForegroundColor DarkGray
    Write-Host ""
}

function Mostrar-Erro {
    param(
        [string]$Mensagem
    )

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" -ForegroundColor DarkRed
    Write-Host "       NAO FOI POSSIVEL CONCLUIR" -ForegroundColor Red
    Write-Host "  =======================================" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "  $Mensagem" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Fechando automaticamente em 5 segundos..." -ForegroundColor DarkGray
    Write-Host ""
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

    # Primeiro solicita o encerramento normal
    if (Test-Path $SteamExe) {
        try {
            Start-Process `
                -FilePath $SteamExe `
                -ArgumentList "-shutdown" `
                -WindowStyle Hidden `
                -ErrorAction SilentlyContinue
        }
        catch {}
    }

    Start-Sleep -Seconds 4

    # Interrompe o serviço da Steam
    $ServicoSteam = Get-Service `
        -Name "Steam Client Service" `
        -ErrorAction SilentlyContinue

    if (-not $ServicoSteam) {
        $ServicoSteam = Get-Service `
            -DisplayName "Steam Client Service" `
            -ErrorAction SilentlyContinue
    }

    if ($ServicoSteam -and $ServicoSteam.Status -ne "Stopped") {
        Stop-Service `
            -InputObject $ServicoSteam `
            -Force `
            -ErrorAction SilentlyContinue

        try {
            $ServicoSteam.WaitForStatus(
                "Stopped",
                [TimeSpan]::FromSeconds(10)
            )
        }
        catch {}
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

    # Encerra os processos e os processos filhos
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

    # Confirma que tudo foi realmente encerrado
    $TempoLimite = (Get-Date).AddSeconds(20)

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
    while ((Get-Date) -lt $TempoLimite)

    $Restantes = Get-Process `
        -Name $ProcessosSteam `
        -ErrorAction SilentlyContinue

    if ($Restantes) {
        throw "Nao foi possivel encerrar completamente a Steam."
    }

    Start-Sleep -Seconds 2
}

function Reiniciar-Steam {
    param(
        [string]$SteamPath
    )

    $SteamExe = Join-Path $SteamPath "steam.exe"

    if (-not (Test-Path $SteamExe)) {
        return
    }

    # Aguarda um pouco antes de reabrir
    Start-Sleep -Seconds 3

    # Tenta iniciar o serviço, mas não considera falha fatal
    $ServicoSteam = Get-Service `
        -Name "Steam Client Service" `
        -ErrorAction SilentlyContinue

    if (-not $ServicoSteam) {
        $ServicoSteam = Get-Service `
            -DisplayName "Steam Client Service" `
            -ErrorAction SilentlyContinue
    }

    if ($ServicoSteam -and $ServicoSteam.Status -ne "Running") {
        Start-Service `
            -InputObject $ServicoSteam `
            -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2
    }

    # Abre a Steam sem transformar demora na inicialização em erro
    Start-Process `
        -FilePath $SteamExe `
        -WorkingDirectory $SteamPath `
        -ErrorAction SilentlyContinue
}

# Solicita administrador automaticamente
if (-not (Testar-Administrador)) {
    Mostrar-TelaInicial

    Write-Host "  Solicitando permissao de administrador..." -ForegroundColor Cyan
    Write-Host ""

    try {
        $ComandoElevado = "irm '$ScriptUrl' | iex"

        $BytesElevados = [Text.Encoding]::Unicode.GetBytes(
            $ComandoElevado
        )

        $ComandoElevadoCodificado = [Convert]::ToBase64String(
            $BytesElevados
        )

        $PowerShellExe = Join-Path `
            $env:SystemRoot `
            "System32\WindowsPowerShell\v1.0\powershell.exe"

        Start-Process `
            -FilePath $PowerShellExe `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-EncodedCommand", $ComandoElevadoCodificado
            )

        Start-Sleep -Seconds 1
        [Environment]::Exit(0)
    }
    catch {
        Mostrar-Erro -Mensagem "A permissao de administrador nao foi concedida."

        Start-Sleep -Seconds 5
        [Environment]::Exit(1)
    }
}

Mostrar-TelaInicial

try {
    Mostrar-Etapa "Verificando a instalacao..."

    $SteamPath = Encontrar-Steam

    if (-not $SteamPath) {
        throw "A Steam nao foi encontrada neste computador."
    }

    Mostrar-Etapa "Encerrando completamente a Steam..."

    Encerrar-Steam -SteamPath $SteamPath

    Mostrar-Etapa "Preparando a atualizacao..."

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

    Mostrar-Etapa "Obtendo os dados necessarios..."

    Invoke-WebRequest `
        -Uri $ZipUrl `
        -OutFile $ArquivoZip `
        -UseBasicParsing `
        -ErrorAction Stop

    if (-not (Test-Path $ArquivoZip)) {
        throw "Nao foi possivel baixar a atualizacao."
    }

    if ((Get-Item $ArquivoZip).Length -eq 0) {
        throw "A atualizacao recebida esta vazia."
    }

    Mostrar-Etapa "Aplicando a atualizacao..."

    Expand-Archive `
        -Path $ArquivoZip `
        -DestinationPath $PastaExtraida `
        -Force `
        -ErrorAction Stop

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
        throw "O conteudo recebido nao e valido."
    }

    $Destino = Join-Path $SteamPath $NomePasta

    if (Test-Path $Destino) {
        Remove-Item `
            -Path $Destino `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }

    Copy-Item `
        -LiteralPath $PastaEncontrada.FullName `
        -Destination $SteamPath `
        -Recurse `
        -Force `
        -ErrorAction Stop

    if (-not (Test-Path $Destino)) {
        throw "Nao foi possivel aplicar a atualizacao."
    }

    Mostrar-Etapa "Finalizando..."

    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    # Reiniciar a Steam não é tratado como falha da instalação
    Reiniciar-Steam -SteamPath $SteamPath

    Mostrar-Sucesso

    Start-Sleep -Seconds 3
    [Environment]::Exit(0)
}
catch {
    $MensagemErro = $_.Exception.Message

    if ([string]::IsNullOrWhiteSpace($MensagemErro)) {
        $MensagemErro = "Ocorreu um erro durante a atualizacao."
    }

    Mostrar-Erro -Mensagem $MensagemErro

    Start-Sleep -Seconds 5
    [Environment]::Exit(1)
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
