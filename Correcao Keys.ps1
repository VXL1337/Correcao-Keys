$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Forca TLS moderno para os downloads
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12

# Nome real do arquivo hospedado no GitHub
$ScriptUrlBase = "https://raw.githubusercontent.com/VXL1337/Correcao-Keys/main/Correcao%20Keys.ps1"

# Link direto do pacote
$ZipUrl = "https://pandorakeys.com/admin/Correcao.zip"

# Pasta existente dentro do ZIP
$NomePasta = "opensteamtool"

# Diretorios temporarios
$PastaTemporaria = Join-Path $env:TEMP "SteamFix"
$ArquivoZip = Join-Path $PastaTemporaria "correcao.zip"
$PastaExtraida = Join-Path $PastaTemporaria "extraido"
$ArquivoLog = Join-Path $env:TEMP "SteamFix-erro.txt"

$EtapaAtual = "iniciando"

function Testar-Administrador {
    $Identidade = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object `
        Security.Principal.WindowsPrincipal($Identidade)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Mostrar-Cabecalho {
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
}

function Mostrar-Etapa {
    param(
        [string]$Mensagem
    )

    Write-Host "  $Mensagem" -ForegroundColor Cyan
}

function Mostrar-Sucesso {
    param(
        [bool]$SteamIniciada
    )

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" `
        -ForegroundColor DarkGreen
    Write-Host "          ATUALIZACAO CONCLUIDA" `
        -ForegroundColor Green
    Write-Host "  =======================================" `
        -ForegroundColor DarkGreen
    Write-Host ""

    if ($SteamIniciada) {
        Write-Host "  Tudo pronto! A Steam foi reiniciada." `
            -ForegroundColor White
    }
    else {
        Write-Host "  Atualizacao concluida." `
            -ForegroundColor White
        Write-Host "  Abra a Steam normalmente." `
            -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  Fechando automaticamente em 3 segundos..." `
        -ForegroundColor DarkGray
    Write-Host ""
}

function Mostrar-Erro {
    param(
        [string]$Etapa
    )

    Clear-Host

    Write-Host ""
    Write-Host "  =======================================" `
        -ForegroundColor DarkRed
    Write-Host "       NAO FOI POSSIVEL CONCLUIR" `
        -ForegroundColor Red
    Write-Host "  =======================================" `
        -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "  Falha durante: $Etapa." `
        -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Fechando automaticamente em 5 segundos..." `
        -ForegroundColor DarkGray
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

    # Solicita primeiro o fechamento normal
    if (Test-Path $SteamExe) {
        try {
            Start-Process `
                -FilePath $SteamExe `
                -ArgumentList "-shutdown" `
                -WindowStyle Hidden `
                -ErrorAction SilentlyContinue |
                Out-Null
        }
        catch {}
    }

    Start-Sleep -Seconds 4

    # Processos do cliente que precisam ser reiniciados
    $ProcessosSteam = @(
        "steam",
        "steamwebhelper",
        "GameOverlayUI",
        "steamerrorreporter",
        "steamerrorreporter64",
        "steam_monitor",
        "steamxboxutil",
        "steamxboxutil64"
    )

    $TaskKill = Join-Path `
        $env:SystemRoot `
        "System32\taskkill.exe"

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

    # Aguarda todos os processos encerrarem
    $TempoLimite = (Get-Date).AddSeconds(15)

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
        throw "A Steam nao foi encerrada completamente."
    }

    Start-Sleep -Seconds 2
}

function Baixar-Arquivo {
    param(
        [string]$Url,
        [string]$Destino
    )

    if (Test-Path $Destino) {
        Remove-Item `
            -Path $Destino `
            -Force `
            -ErrorAction SilentlyContinue
    }

    try {
        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $Destino `
            -UseBasicParsing `
            -TimeoutSec 60 `
            -Headers @{
                "User-Agent" = "Mozilla/5.0"
                "Cache-Control" = "no-cache"
            } `
            -ErrorAction Stop
    }
    catch {
        if (Test-Path $Destino) {
            Remove-Item `
                -Path $Destino `
                -Force `
                -ErrorAction SilentlyContinue
        }

        $Curl = Get-Command `
            "curl.exe" `
            -ErrorAction SilentlyContinue

        if (-not $Curl) {
            throw "Falha ao baixar a atualizacao."
        }

        & $Curl.Source `
            -L `
            --fail `
            --silent `
            --show-error `
            --output $Destino `
            $Url

        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao baixar a atualizacao."
        }
    }

    if (-not (Test-Path $Destino)) {
        throw "O download nao foi criado."
    }

    $Arquivo = Get-Item $Destino

    if ($Arquivo.Length -lt 4) {
        throw "O download recebido esta vazio."
    }
}

function Validar-Zip {
    param(
        [string]$Caminho
    )

    $Fluxo = [System.IO.File]::OpenRead($Caminho)

    try {
        $PrimeiroByte = $Fluxo.ReadByte()
        $SegundoByte = $Fluxo.ReadByte()
    }
    finally {
        $Fluxo.Dispose()
    }

    # Arquivos ZIP validos comecam com PK
    if (
        $PrimeiroByte -ne 0x50 -or
        $SegundoByte -ne 0x4B
    ) {
        throw "O servidor nao retornou um ZIP valido."
    }
}

function Iniciar-Steam {
    param(
        [string]$SteamPath
    )

    $SteamExe = Join-Path $SteamPath "steam.exe"

    if (-not (Test-Path $SteamExe)) {
        return $false
    }

    Start-Sleep -Seconds 2

    for ($Tentativa = 1; $Tentativa -le 3; $Tentativa++) {
        try {
            Start-Process `
                -FilePath $SteamExe `
                -WorkingDirectory $SteamPath `
                -ErrorAction SilentlyContinue |
                Out-Null
        }
        catch {}

        Start-Sleep -Seconds 3

        $ProcessoSteam = Get-Process `
            -Name "steam" `
            -ErrorAction SilentlyContinue

        if ($ProcessoSteam) {
            return $true
        }

        try {
            Start-Process `
                -FilePath "steam://open/main" `
                -ErrorAction SilentlyContinue |
                Out-Null
        }
        catch {}

        Start-Sleep -Seconds 2
    }

    return $false
}

# Solicita administrador automaticamente
if (-not (Testar-Administrador)) {
    Mostrar-Cabecalho

    Write-Host "  Solicitando permissao de administrador..." `
        -ForegroundColor Cyan
    Write-Host ""

    try {
        # Adiciona um parametro para evitar cache do GitHub
        $ComandoElevado = (
            "`$url = '${ScriptUrlBase}?ts=' + " +
            "[DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); " +
            "irm `$url | iex"
        )

        $Bytes = [Text.Encoding]::Unicode.GetBytes(
            $ComandoElevado
        )

        $ComandoCodificado = [Convert]::ToBase64String(
            $Bytes
        )

        $PowerShellExe = Join-Path `
            $env:SystemRoot `
            "System32\WindowsPowerShell\v1.0\powershell.exe"

        Start-Process `
            -FilePath $PowerShellExe `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-EncodedCommand",
                $ComandoCodificado
            ) |
            Out-Null

        Start-Sleep -Seconds 1
        [Environment]::Exit(0)
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
        Write-Host "  A permissao de administrador e necessaria." `
            -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Fechando em 5 segundos..." `
            -ForegroundColor DarkGray

        Start-Sleep -Seconds 5
        [Environment]::Exit(1)
    }
}

Mostrar-Cabecalho

try {
    $EtapaAtual = "verificar a instalacao"
    Mostrar-Etapa "Verificando a instalacao..."

    $SteamPath = Encontrar-Steam

    if (-not $SteamPath) {
        throw "A Steam nao foi encontrada."
    }

    $EtapaAtual = "encerrar a Steam"
    Mostrar-Etapa "Encerrando completamente a Steam..."

    Encerrar-Steam -SteamPath $SteamPath

    $EtapaAtual = "preparar a atualizacao"
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

    $EtapaAtual = "baixar a atualizacao"
    Mostrar-Etapa "Obtendo os dados necessarios..."

    Baixar-Arquivo `
        -Url $ZipUrl `
        -Destino $ArquivoZip

    Validar-Zip -Caminho $ArquivoZip

    $EtapaAtual = "extrair a atualizacao"
    Mostrar-Etapa "Aplicando a correcao..."

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
        throw "O conteudo do pacote nao e valido."
    }

    $Destino = Join-Path $SteamPath $NomePasta

    $EtapaAtual = "instalar a atualizacao"

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
        throw "A atualizacao nao foi instalada."
    }

    $EtapaAtual = "finalizar"
    Mostrar-Etapa "Finalizando..."

    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    $SteamIniciada = Iniciar-Steam `
        -SteamPath $SteamPath

    Mostrar-Sucesso `
        -SteamIniciada $SteamIniciada

    Start-Sleep -Seconds 3
    [Environment]::Exit(0)
}
catch {
    try {
        @(
            "Data: $(Get-Date)"
            "Etapa: $EtapaAtual"
            "Erro: $($_.Exception.Message)"
            ""
            ($_ | Out-String)
        ) | Set-Content `
            -Path $ArquivoLog `
            -Encoding UTF8 `
            -Force
    }
    catch {}

    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Mostrar-Erro -Etapa $EtapaAtual

    Start-Sleep -Seconds 5
    [Environment]::Exit(1)
}
