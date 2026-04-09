---
displayed_sidebar: janusSidebar
title: Erros Comuns
---

## Entidade não reconhecida

- Sintoma: operação CRUD falha sem mapear tabela.
- Causa provável: entidade não registrada no initialization.
- Ação: registrar com TRegisterClass.RegisterEntity.

## SQL com driver incorreto

- Sintoma: sintaxe SQL incompatível com o banco.
- Causa provável: driver não resolvido corretamente na conexão.
- Ação: validar factory de conexão e enum do driver.

## ELazyLoadException ao acessar propriedade lazy

- Sintoma: acessar `.Value` de uma associação lazy falha com mensagem sobre sessão destruída.
- Causa provável: `ILazySessionToken` foi invalidado antes do primeiro acesso ao proxy.
- Ação: garantir que o acesso ocorra com a sessão ainda viva; em DataSet e REST, evitar reutilizar objetos fora do ciclo gerenciado pelo framework.

## Associação lazy não recarrega após trocar a linha do DataSet

- Sintoma: a entidade da linha anterior permanece em cache depois de navegar para outro registro.
- Causa provável: o proxy não foi reinjetado para a nova PK ou o objeto foi reutilizado fora do fluxo do adapter.
- Ação: usar o fluxo padrão do `TManagerDataSet` e deixar o framework aplicar `ILazyProxyResettable` durante a mudança de registro. Na `v2.19.2`, o caminho `Invoke -> Reset -> Invoke` foi estabilizado para produzir novo carregamento de forma determinística.

## Entidade marcada com [View] retorna tabela indevida

- Sintoma: caminhos de mapeamento tentam resolver tabela física para uma entidade anotada apenas com `[View]`.
- Causa provável: contrato de helper sem diferenciação explícita entre entidades `[Table]` e `[View]`.
- Ação: usar versão `v2.19.2` ou superior, onde `TObjectHelper.GetTable` retorna `nil` para entidades view-only e o mapeamento de view segue por `GetMappingView`.

## Bind inválido em UPDATE/INSERT

- Sintoma: erro de parâmetro na execução.
- Causa provável: mismatch entre placeholders e parâmetros.
- Ação: revisar mapeamento de campos e geração de parâmetros no comando.

## Erro de compilação após migração Criteria → FluentSQL

- Sintoma: `Unit not found: Janus.Criteria.pas` ou referências a `ICriteria`, `CreateCriteria`.
- Causa: `Source/Criteria/*.pas` foi removido definitivamente em v2.18.6.
- Ação: substituir todos os usos de `ICriteria`/`CreateCriteria` por `TCQ(conexao)` com a API FluentSQL. Consulte o [Guia FluentSQL](../guides/criteria-fluentsql).

## E2003 Undeclared identifier: `Supports` no smoke test

- Sintoma: compilação falha em `TestSmokeLazyLoading.pas` com `E2003 Undeclared identifier: 'Supports'`.
- Causa provável: unit necessária para resolução de `Supports` ausente no `uses` do teste.
- Ação: incluir `SysUtils` no `uses` do teste e recompilar `Test/Delphi/JanusSmoke.dpr`.

## F2613 Unit `SysUtils` not found no gate final

- Sintoma: o gate final de release falha ao compilar `JanusSmoke` com `F2613 Unit 'SysUtils' not found`.
- Causa provável: ambiente Delphi não inicializado corretamente no script de compilação.
- Ação: executar o fluxo oficial de build/smoke com os scripts de suporte da release (`.claude/tmp-compile-janussmoke.cmd` e `.claude/tmp/build-janussmoke.cmd`) para garantir resolução de paths do compilador.

> Para troubleshooting operacional detalhado, consulte [Manual do Usuário - Erros Comuns](../user/troubleshooting/common-errors).
