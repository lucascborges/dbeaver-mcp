/**
 * schema.ts — MCP tools for schema inspection and performance monitoring.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as dbeaver from "../dbeaver.js";
import { checkPermission } from "../permissions.js";
import { runQuery } from "../mysql.js";

function text(data: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}

export function registerSchemaTools(server: McpServer): void {
  server.tool(
    "list_tables",
    "Lista tabelas de um banco de dados",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
      database: z.string().optional().describe("Nome do banco (usa o padrão da conexão se omitido)"),
    },
    async ({ connection, database }) => {
      try {
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        const permError = checkPermission(connection, "SHOW TABLES");
        if (permError) return text({ error: permError });
        const db = database || info.database;
        if (!db) return text({ error: "Informe o banco de dados ('database')." });
        const result = await runQuery(info, `SHOW TABLES FROM \`${db}\``);
        const tables = result.rows.map((r) => Object.values(r)[0]);
        return text({ database: db, tables, total: tables.length });
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );

  server.tool(
    "describe_table",
    "Descreve estrutura, índices e CREATE TABLE",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
      table: z.string().describe("Nome da tabela"),
      database: z.string().optional().describe("Nome do banco (usa o padrão da conexão se omitido)"),
    },
    async ({ connection, table, database }) => {
      try {
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        for (const op of ["DESCRIBE", "SHOW"]) {
          const permError = checkPermission(connection, `${op} x`);
          if (permError) return text({ error: permError });
        }
        const db = database || info.database;
        const columns = await runQuery(info, `DESCRIBE \`${db}\`.\`${table}\``);
        const indexes = await runQuery(info, `SHOW INDEX FROM \`${db}\`.\`${table}\``);
        const create = await runQuery(info, `SHOW CREATE TABLE \`${db}\`.\`${table}\``);
        const createSql = create.rows[0] ? Object.values(create.rows[0])[1] : "";
        return text({ table, database: db, columns: columns.rows, indexes: indexes.rows, create_sql: createSql });
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );

  server.tool(
    "explain_query",
    "Roda EXPLAIN e aponta red flags",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
      sql: z.string().describe("Query SQL para analisar"),
    },
    async ({ connection, sql }) => {
      try {
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        const permError = checkPermission(connection, "EXPLAIN x");
        if (permError) return text({ error: permError });
        const basic = await runQuery(info, `EXPLAIN ${sql.trim()}`);
        const redFlags: string[] = [];
        for (const row of basic.rows) {
          const t = row.type || "";
          const extra = row.Extra || "";
          if (t === "ALL") redFlags.push(`Full table scan na tabela '${row.table || ""}'`);
          if (extra.includes("Using filesort")) redFlags.push(`Using filesort na tabela '${row.table || ""}'`);
          if (extra.includes("Using temporary")) redFlags.push(`Using temporary na tabela '${row.table || ""}'`);
        }
        return text({ plan: basic.rows, red_flags: redFlags });
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );

  server.tool(
    "show_processlist",
    "Mostra queries em execução no servidor",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
    },
    async ({ connection }) => {
      try {
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        const permError = checkPermission(connection, "SHOW PROCESSLIST");
        if (permError) return text({ error: permError });
        const result = await runQuery(info, "SHOW FULL PROCESSLIST");
        return text(result);
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );

  server.tool(
    "show_slow_queries",
    "Lista queries lentas do performance_schema",
    {
      connection: z.string().describe("Nome ou ID da conexão"),
      limit: z.number().optional().default(20).describe("Número máximo de resultados"),
    },
    async ({ connection, limit }) => {
      try {
        const info = dbeaver.getConnectionInfo(connection);
        if (!info) return text({ error: `Conexão '${connection}' não encontrada.` });
        const permError = checkPermission(connection, "SELECT FROM performance_schema");
        if (permError) return text({ error: permError });
        const sql = `
          SELECT digest_text, count_star, avg_timer_wait/1e12 AS avg_sec,
                 max_timer_wait/1e12 AS max_sec, sum_rows_examined
          FROM performance_schema.events_statements_summary_by_digest
          ORDER BY avg_timer_wait DESC
          LIMIT ${limit}
        `;
        const result = await runQuery(info, sql);
        return text(result);
      } catch (e: any) {
        return text({ error: e.message });
      }
    },
  );
}
