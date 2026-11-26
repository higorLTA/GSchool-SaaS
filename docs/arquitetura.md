# Arquitetura do GSchool

## Visão geral

- **Frontend:** React + TypeScript + Vite + Tailwind. Interface em português do Brasil.
- **Backend:** Supabase — Postgres (com RLS), Auth, Storage e Edge Functions.
- **Integrações (módulos `ee/`):** Asaas (cobranças), WhatsApp Cloud API, Resend (e-mail), IA.
- **CI/CD:** GitHub Actions.

O código (tabelas, colunas, funções, componentes) é escrito em inglês; tudo o que o usuário vê é em português.

## Multi-tenant

Todas as escolas compartilham o mesmo banco. Cada registro pertence a uma escola (`institution_id`) e o **Row Level Security** do Postgres garante que cada usuário só acesse os dados das escolas com as quais tem vínculo ativo. Decisão registrada em [ADR 0002](decisoes/0002-isolamento-multi-tenant-rls.md).

## Modelo de dados

| Módulo | Documentação | Status |
|---|---|---|
| Núcleo (escolas, perfis, vínculos, auditoria) | [banco/nucleo.md](banco/nucleo.md) | ✅ |
| Pessoas e acadêmico (alunos, responsáveis, turmas, matrículas) | — | Tópico 3 |
| Financeiro | — | Tópico 5 |
| Comunicação (WhatsApp) | — | Tópico 7 |

## Decisões

- [ADR 0001 — Open-core](decisoes/0001-open-core.md)
- [ADR 0002 — Isolamento multi-tenant com RLS](decisoes/0002-isolamento-multi-tenant-rls.md)
