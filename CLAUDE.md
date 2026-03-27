# dbeaver-mcp

MCP server que expõe conexões DBeaver ao Claude como tools. Lê credenciais criptografadas do DBeaver em memória — nunca persiste senhas em disco.

## Estrutura

```
dbeaver-mcp/
├── dbeaver.py          # Lê/escreve data-sources.json e credentials-config.json
├── scripts/server.py   # MCP server stdio — 13 tools
├── install/            # Scripts de instalação por OS
│   ├── mac.sh          # macOS: launchd + claude mcp add
│   ├── linux.sh        # Linux: systemd user + claude mcp add
│   └── windows.ps1     # Windows: PowerShell
├── references/
│   ├── dbeaver/        # credentials.md, datasources.md, workspace.md
│   └── mysql/          # 15 arquivos de referência MySQL (planetscale/database-skills)
├── SKILL.md            # Skill para agentes AI
└── requirements.txt    # mysql-connector-python, pycryptodome
```

## Dependências

```bash
pip install mysql-connector-python pycryptodome
```

## Rodar o servidor

```bash
python scripts/server.py
```

O servidor usa protocolo MCP via stdio (JSON-RPC 2.0).

## Registrar no Claude Code

```bash
claude mcp add dbeaver-mcp -- python /caminho/para/dbeaver-mcp/scripts/server.py
```

## Registrar no Claude Desktop

```json
{
  "mcpServers": {
    "dbeaver-mcp": {
      "command": "python",
      "args": ["/caminho/para/dbeaver-mcp/scripts/server.py"]
    }
  }
}
```

## Tools disponíveis

| Tool | Descrição |
|---|---|
| `list_connections` | Lista conexões DBeaver (sem senhas) |
| `get_connection` | Detalhes de uma conexão pelo nome |
| `add_connection` | Adiciona nova conexão |
| `edit_connection` | Edita host/porta/banco/usuário/senha |
| `remove_connection` | Remove uma conexão |
| `test_connection` | Testa conectividade |
| `run_query` | SELECT/SHOW/EXPLAIN (somente leitura) |
| `run_write` | INSERT/UPDATE/DELETE/DDL (requer confirmação) |
| `list_tables` | Lista tabelas de um banco |
| `describe_table` | Estrutura, índices e CREATE TABLE |
| `explain_query` | EXPLAIN com análise de red flags |
| `show_processlist` | Queries em execução |
| `show_slow_queries` | Queries lentas do performance_schema |

## Segurança

- Senhas descriptografadas em memória, nunca logadas
- `credentials-config.json` e `data-sources.json` estão no `.gitignore`
- `run_write` exige `confirmed: true` antes de executar
- `run_query` bloqueia INSERT/UPDATE/DELETE/DROP

## Caminhos do workspace DBeaver por OS

| OS | Caminho |
|---|---|
| macOS | `~/Library/DBeaverData/workspace6/General/.dbeaver/` |
| Linux | `~/.local/share/DBeaverData/workspace6/General/.dbeaver/` |
| Windows | `%APPDATA%\DBeaverData\workspace6\General\.dbeaver\` |

## Testar sem Claude

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | python scripts/server.py
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_connections","arguments":{}}}' | python scripts/server.py
```
