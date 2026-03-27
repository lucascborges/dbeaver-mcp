#!/usr/bin/env bash
# install/linux.sh — Instala o dbeaver-mcp no Linux
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="dbeaver-mcp"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "=== dbeaver-mcp — Instalação Linux ==="
echo ""

# 1. Node.js
if ! command -v node &>/dev/null; then
  echo "ERRO: Node.js não encontrado."
  echo "Instale com: sudo apt install nodejs npm  (Debian/Ubuntu)"
  echo "         ou: sudo dnf install nodejs       (Fedora/RHEL)"
  echo "         ou: https://nodejs.org/"
  exit 1
fi
echo "✓ Node.js: $(node --version)"

# 2. npm
if ! command -v npm &>/dev/null; then
  echo "ERRO: npm não encontrado."
  echo "Instale com: sudo apt install npm"
  exit 1
fi
echo "✓ npm: $(npm --version)"

# 3. Dependências
echo ""
echo "Instalando dependências Node.js..."
cd "$REPO_DIR" && npm install --production
echo "✓ Dependências instaladas"

# 4. Build
echo ""
echo "Compilando TypeScript..."
cd "$REPO_DIR" && npm run build
echo "✓ Build concluído"

# 5. Verificar workspace DBeaver
echo ""
echo "Verificando workspace do DBeaver..."
node -e "
  const { findWorkspace } = require('$REPO_DIR/dist/dbeaver.js');
  try { findWorkspace(); console.log('✓ Workspace encontrado'); }
  catch(e) { console.log('⚠ ' + e.message.split('\n')[0]); }
" 2>/dev/null || echo "⚠ Workspace do DBeaver não encontrado."

# 6. Criar diretório de configuração e settings padrão
echo ""
echo "Configurando diretório ~/.dbeaver-mcp..."
mkdir -p "$HOME/.dbeaver-mcp"
if [ ! -f "$HOME/.dbeaver-mcp/settings.json" ]; then
  cp "$REPO_DIR/settings.example.json" "$HOME/.dbeaver-mcp/settings.json"
  echo "✓ settings.json criado em ~/.dbeaver-mcp/"
else
  echo "✓ settings.json já existe em ~/.dbeaver-mcp/"
fi

# 7. Systemd user service (opcional, sem sudo)
echo ""
if command -v systemctl &>/dev/null; then
  echo "Instalando serviço systemd (usuário)..."
  mkdir -p "$SYSTEMD_USER_DIR"
  cat > "$SYSTEMD_USER_DIR/$SERVICE_NAME.service" <<EOF
[Unit]
Description=DBeaver MCP Server
After=graphical-session.target

[Service]
Type=simple
ExecStart=$(command -v node) $REPO_DIR/dist/index.js
WorkingDirectory=$REPO_DIR
Restart=no
StandardError=journal

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload 2>/dev/null || true
  echo "✓ Serviço systemd criado: ~/.config/systemd/user/$SERVICE_NAME.service"
  echo "  Para ativar: systemctl --user enable $SERVICE_NAME"
else
  echo "systemd não disponível. O servidor será iniciado sob demanda pelo Claude."
fi

# 8. Claude Code
echo ""
if command -v claude &>/dev/null; then
  echo "Registrando no Claude Code..."
  claude mcp add dbeaver-mcp -- npx dbeaver-mcp 2>/dev/null && \
    echo "✓ Adicionado ao Claude Code" || \
    echo "⚠ Adicione manualmente: claude mcp add dbeaver-mcp -- npx dbeaver-mcp"
else
  echo "Claude Code não encontrado. Adicione manualmente:"
  echo "  claude mcp add dbeaver-mcp -- npx dbeaver-mcp"
fi

# 9. Claude Desktop (Linux)
CLAUDE_DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
if [ -f "$CLAUDE_DESKTOP_CONFIG" ]; then
  echo ""
  echo "Claude Desktop detectado. Adicione em claude_desktop_config.json:"
  echo '  "mcpServers": {'
  echo '    "dbeaver-mcp": {'
  echo '      "command": "npx",'
  echo '      "args": ["dbeaver-mcp"]'
  echo '    }'
  echo '  }'
fi

echo ""
echo "=== Instalação concluída! ==="
echo ""
echo "Teste rápido:"
echo "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' | node $REPO_DIR/dist/index.js"
