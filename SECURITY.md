# Política de segurança

O GSchool lida com dados de escolas, de crianças e de suas famílias. Levamos relatos de vulnerabilidade a sério.

## Versões com suporte

O projeto está em desenvolvimento. Correções de segurança são aplicadas na branch `develop` e levadas para `main` na versão seguinte.

## Como relatar uma vulnerabilidade

**Não abra uma issue pública** para relatar falhas de segurança.

Use o recurso de relato privado do GitHub: aba **Security** → **Report a vulnerability**. Inclua, se possível:

- descrição do problema e do impacto (por exemplo, acesso a dados de outra escola);
- passos para reproduzir;
- versão, branch ou commit afetado.

Você receberá uma resposta em até 7 dias. Pedimos que a falha não seja divulgada até que a correção esteja disponível.

## Boas práticas adotadas

- Row Level Security em todas as tabelas com dados de escolas, com testes automatizados de isolamento.
- Nenhum segredo versionado; chaves secretas usadas somente no servidor.
- Dados fictícios em desenvolvimento.
- Alertas do Dependabot e varredura de segredos (*secret scanning*) ativados no repositório.
