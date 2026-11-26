# ADR 0002 — Isolamento multi-tenant com RLS e tabela de vínculos

- **Status:** aceito
- **Data:** 26/11/2026

## Contexto

O GSchool atende várias escolas no mesmo sistema. Os dados de uma escola (alunos, responsáveis, cobranças, mensagens) não podem, em hipótese alguma, aparecer para outra. Muitos desses dados são de crianças, o que torna o vazamento grave também do ponto de vista da LGPD.

Uma mesma pessoa pode trabalhar em mais de uma escola e ter mais de um papel em cada uma (ex.: diretora que também dá aula).

## Decisão

- **Um único banco Postgres (Supabase)**, com todas as escolas nas mesmas tabelas, separadas pela coluna `institution_id`.
- **Row Level Security (RLS) ativo em todas as tabelas**, criado na mesma migration da tabela (a tabela nasce fechada).
- **Tabela de vínculos `institution_users`** (pessoa × escola × papel) como fonte da verdade sobre quem pertence a qual escola.
- **Funções auxiliares** `private.is_member` e `private.has_role`, `security definer` com `search_path` vazio, num schema não exposto pela API. Todas as policies usam essas funções.
- **Testes de isolamento** em SQL que simulam usuários de escolas diferentes e precisam passar antes de qualquer merge.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Um banco por escola | Custo e operação multiplicados por escola (migrations, backups, conexões); inviável no plano do Supabase e para um time pequeno. |
| Um schema por escola | Migrations precisam rodar em N schemas; a API do Supabase não lida bem com schemas dinâmicos; relatórios da plataforma ficam complexos. |
| Filtrar por escola só no frontend/backend | Um único esquecimento de `where institution_id = ...` vaza dados. Com RLS, o banco aplica a regra mesmo se o código errar. |
| `institution_id` direto em `profiles` | Não permite a mesma pessoa em várias escolas nem vários papéis. |

## Consequências

- **Positivas:** a segurança fica no banco, não depende de cada tela; a regra é escrita uma vez (nas funções) e reaproveitada; o modelo suporta várias escolas por pessoa; custo de uma única base.
- **Negativas:** toda tabela nova precisa de `institution_id`, RLS e policies (e testes) — esquecer é um risco, mitigado pelos testes e pelo Security Advisor; as funções auxiliares rodam em toda consulta, por isso `institution_users` tem índice por `profile_id` e as policies usam `(select auth.uid())`.
- Toda tabela nova do domínio deve seguir este padrão.
