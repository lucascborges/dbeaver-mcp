# install/windows.ps1 — Instala o dbeaver-mcp no Windows
# Execute como: powershell -ExecutionPolicy Bypass -File install\windows.ps1
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $PSScriptRoot

Write-Host "=== dbeaver-mcp — Instalacao Windows ===" -ForegroundColor Cyan
Write-Host ""

# 1. Node.js
$NodeCmd = $null
foreach ($candidate in @("node")) {
    try {
        $ver = & $candidate --version 2>&1
        if ($ver -match "^v\d+") {
            $NodeCmd = $candidate
            Write-Host "OK Node.js: $ver" -ForegroundColor Green
            break
        }
    } catch {}
}
if (-not $NodeCmd) {
    Write-Host "ERRO: Node.js nao encontrado." -ForegroundColor Red
    Write-Host "Instale em: https://nodejs.org/"
    exit 1
}

# 2. npm
$NpmCmd = $null
try {
    $npmVer = & npm --version 2>&1
    $NpmCmd = "npm"
    Write-Host "OK npm: $npmVer" -ForegroundColor Green
} catch {
    Write-Host "ERRO: npm nao encontrado." -ForegroundColor Red
    exit 1
}

# 3. Dependencias
Write-Host ""
Write-Host "Instalando dependencias Node.js..."
Push-Location $RepoDir
& npm install --production
Pop-Location
Write-Host "OK Dependencias instaladas" -ForegroundColor Green

# 4. Build
Write-Host ""
Write-Host "Compilando TypeScript..."
Push-Location $RepoDir
& npm run build
Pop-Location
Write-Host "OK Build concluido" -ForegroundColor Green

# 5. Verificar workspace DBeaver
Write-Host ""
Write-Host "Verificando workspace do DBeaver..."
$testScript = @"
try {
  const { findWorkspace } = require('$($RepoDir -replace '\\','/')/dist/dbeaver.js');
  findWorkspace();
  console.log('OK Workspace encontrado');
} catch(e) {
  console.log('AVISO: ' + e.message.split('\n')[0]);
}
"@
& $NodeCmd -e $testScript

# 6. Criar diretorio de configuracao e settings padrao
Write-Host ""
Write-Host "Configurando diretorio ~/.dbeaver-mcp..."
$ConfigDir = "$env:USERPROFILE\.dbeaver-mcp"
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}
$SettingsFile = "$ConfigDir\settings.json"
if (-not (Test-Path $SettingsFile)) {
    Copy-Item "$RepoDir\settings.example.json" $SettingsFile
    Write-Host "OK settings.json criado em $ConfigDir" -ForegroundColor Green
} else {
    Write-Host "OK settings.json ja existe em $ConfigDir" -ForegroundColor Green
}

# 7. Criar atalho de registro no Claude
Write-Host ""
Write-Host "Criando atalho de registro no Claude..."

$RegisterScript = @"
@echo off
echo Registrando dbeaver-mcp no Claude Code...
claude mcp add dbeaver-mcp -- npx dbeaver-mcp
echo.
echo Concluido! Reinicie o Claude Code.
pause
"@
$RegisterScript | Out-File -FilePath "$RepoDir\register-claude.bat" -Encoding ASCII
Write-Host "OK Criado register-claude.bat" -ForegroundColor Green

# 8. Claude Code
Write-Host ""
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Write-Host "Registrando no Claude Code..."
    try {
        & claude mcp add dbeaver-mcp -- npx dbeaver-mcp
        Write-Host "OK Adicionado ao Claude Code" -ForegroundColor Green
    } catch {
        Write-Host "AVISO: Nao foi possivel adicionar automaticamente." -ForegroundColor Yellow
        Write-Host "  Execute: register-claude.bat"
    }
} else {
    Write-Host "Claude Code nao encontrado. Execute register-claude.bat apos instalar."
}

# 9. Claude Desktop (Windows)
$ClaudeDesktopConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path $ClaudeDesktopConfig) {
    Write-Host ""
    Write-Host "Claude Desktop detectado. Adicione em claude_desktop_config.json:" -ForegroundColor Yellow
    Write-Host '  "mcpServers": {'
    Write-Host '    "dbeaver-mcp": {'
    Write-Host '      "command": "npx",'
    Write-Host '      "args": ["dbeaver-mcp"]'
    Write-Host '    }'
    Write-Host '  }'
}

Write-Host ""
Write-Host "=== Instalacao concluida! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Teste rapido (PowerShell):"
Write-Host "  '{`"jsonrpc`":`"2.0`",`"id`":1,`"method`":`"tools/list`",`"params`":{}}' | node $RepoDir\dist\index.js"
