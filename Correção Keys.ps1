$ErrorActionPreference = "Stop"

# Link direto para o ZIP
$ZipUrl = "https://pandorakeys.com/admin/Corre%C3%A7%C3%A3o.zip"

# Nome da pasta que existe dentro do ZIP
$NomePasta = "opensteamtool"

# Pasta temporária
$PastaTemporaria = Join-Path $env:TEMP "SteamFix"
$ArquivoZip = Join-Path $PastaTemporaria "Correcao.zip"
$PastaExtraida = Join-Path $PastaTemporaria "extraido"

try {
    Write-Host ""
    Write-Host "Localizando a Steam..." -ForegroundColor Cyan

    # Lista de possíveis locais da Steam
    $PossiveisCaminhos = @()

    # Steam registrada no usuário atual
    $RegistroUsuario = Get-ItemProperty `
        -Path "HKCU:\Software\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($RegistroUsuario.SteamPath) {
        $PossiveisCaminhos += $RegistroUsuario.SteamPath
    }

    # Steam registrada no Windows 64 bits
    $Registro64 = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($Registro64.InstallPath) {
        $PossiveisCaminhos += $Registro64.InstallPath
    }

    # Steam registrada no Windows 32 bits
    $Registro32 = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\Valve\Steam" `
        -ErrorAction SilentlyContinue

    if ($Registro32.InstallPath) {
        $PossiveisCaminhos += $Registro32.InstallPath
    }

    # Caminhos padrões
    if (${env:ProgramFiles(x86)}) {
        $PossiveisCaminhos += "${env:ProgramFiles(x86)}\Steam"
    }

    if ($env:ProgramFiles) {
        $PossiveisCaminhos += "$env:ProgramFiles\Steam"
    }

    if ($env:LOCALAPPDATA) {
        $PossiveisCaminhos += "$env:LOCALAPPDATA\Steam"
    }

    # Seleciona o primeiro caminho que realmente contém steam.exe
    $SteamPath = $PossiveisCaminhos |
        Where-Object {
            $_ -and (Test-Path (Join-Path $_ "steam.exe"))
        } |
        Select-Object -First 1

    if (-not $SteamPath) {
        throw "Não foi possível encontrar automaticamente a instalação da Steam."
    }

    $SteamPath = $SteamPath.TrimEnd("\", "/")

    Write-Host "Steam encontrada em:" -ForegroundColor Green
    Write-Host $SteamPath -ForegroundColor Yellow

    # Fecha a Steam
    Write-Host ""
    Write-Host "Fechando a Steam..." -ForegroundColor Cyan

    $ProcessosSteam = @(
        "steam",
        "steamwebhelper",
        "GameOverlayUI"
    )

    foreach ($Processo in $ProcessosSteam) {
        Get-Process `
            -Name $Processo `
            -ErrorAction SilentlyContinue |
            Stop-Process `
                -Force `
                -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 3

    # Limpa pasta temporária de execução anterior
    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force
    }

    # Cria as pastas temporárias
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

    # Baixa o ZIP
    Write-Host ""
    Write-Host "Baixando a correção..." -ForegroundColor Cyan

    Invoke-WebRequest `
        -Uri $ZipUrl `
        -OutFile $ArquivoZip `
        -UseBasicParsing

    if (-not (Test-Path $ArquivoZip)) {
        throw "O arquivo ZIP não foi baixado."
    }

    if ((Get-Item $ArquivoZip).Length -eq 0) {
        throw "O arquivo ZIP baixado está vazio."
    }

    # Extrai o ZIP
    Write-Host "Extraindo os arquivos..." -ForegroundColor Cyan

    Expand-Archive `
        -Path $ArquivoZip `
        -DestinationPath $PastaExtraida `
        -Force

    # Procura a pasta opensteamtool dentro do ZIP
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
        throw "A pasta '$NomePasta' não foi encontrada dentro do ZIP."
    }

    # Destino final:
    # C:\Program Files (x86)\Steam\opensteamtool
    $Destino = Join-Path $SteamPath $NomePasta

    # Faz backup da pasta antiga, caso exista
    if (Test-Path $Destino) {
        $DataBackup = Get-Date -Format "yyyyMMdd-HHmmss"
        $DestinoBackup = Join-Path `
            $SteamPath `
            "${NomePasta}_backup_$DataBackup"

        Write-Host ""
        Write-Host "Criando backup da instalação antiga..." -ForegroundColor Cyan

        Move-Item `
            -Path $Destino `
            -Destination $DestinoBackup `
            -Force

        Write-Host "Backup criado em:" -ForegroundColor Yellow
        Write-Host $DestinoBackup -ForegroundColor Yellow
    }

    # Copia a pasta completa
    Write-Host ""
    Write-Host "Instalando a correção..." -ForegroundColor Cyan

    Copy-Item `
        -LiteralPath $PastaEncontrada.FullName `
        -Destination $Destino `
        -Recurse `
        -Force

    if (-not (Test-Path $Destino)) {
        throw "A pasta não foi copiada corretamente para a Steam."
    }

    Write-Host ""
    Write-Host "Correção concluída com sucesso!" -ForegroundColor Green
    Write-Host "Pasta instalada em:" -ForegroundColor Green
    Write-Host $Destino -ForegroundColor Yellow

    # Abre a Steam novamente
    $SteamExe = Join-Path $SteamPath "steam.exe"

    if (Test-Path $SteamExe) {
        Write-Host ""
        Write-Host "Abrindo a Steam..." -ForegroundColor Cyan
        Start-Process $SteamExe
    }
}
catch {
    Write-Host ""
    Write-Host "Ocorreu um erro:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if (
        $_.Exception.Message -match
        "acesso|access|permissão|permission"
    ) {
        Write-Host ""
        Write-Host "Abra o PowerShell como administrador e tente novamente." `
            -ForegroundColor Yellow
    }
}
finally {
    # Apaga somente os arquivos temporários
    if (Test-Path $PastaTemporaria) {
        Remove-Item `
            -Path $PastaTemporaria `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}