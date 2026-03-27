/**
 * queries.ts — MCP tools for SQL query execution.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as dbeaver from "../dbeaver.js";
import { extractSqlKeyword, checkPermission } from "../permissions.js";
import { runQuery, runWrite } from "../mysql.js";

const WRITE_KEYWORDS = new Set([
  "INSERT", "UPDATE", "DELETE", "DROP", "TRUNCATE", "ALTER", "CREATE",
]);

function text(data: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}

export function registerQueryTools(server: McpServer): void {
  server.tool(
    "run_query",
    "Executa SELECT/SHOW/EXPLAIN (somente leitura)",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
      sql: z.string().describe("Query SQL (somente leitura)"),
    },
    async ({ connection, sql }) => {
      try {
        const trimmed = sql.trim();
        const keyword = extractSqlKeyword(trimmed);
        if (WRITE_KEYWORDS.has(keyword)) {
          return text({ error: `Use run_write para operações de escrita (${keyword}). run_query é somente leitura.` });
        }
        const permError = checkPermission(connection, trimmed);
        if (permError) return text({ error: permError });
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        const result = await runQuery(info, trimmed);
        return text(result);
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );

  server.tool(
    "run_write",
    "Executa INSERT/UPDATE/DELETE/DDL (requer confirmação)",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
      sql: z.string().describe("Query SQL de escrita"),
      confirmed: z.boolean().optional().default(false).describe("Confirmar execução"),
    },
    async ({ connection, sql, confirmed }) => {
      try {
        const trimmed = sql.trim();
        const permError = checkPermission(connection, trimmed);
        if (permError) return text({ error: permError });
        if (!confirmed) {
          return text({
            requires_confirmation: true,
            message: `Confirme a execução da operação de escrita na conexão '${connection}'.`,
            sql_preview: trimmed.slice(0, 300),
          });
        }
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        const result = await runWrite(info, trimmed);
        return text(result);
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );
}
