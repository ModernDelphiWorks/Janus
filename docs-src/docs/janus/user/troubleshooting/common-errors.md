---
title: Erros Comuns
displayed_sidebar: janusSidebar
---

## Entidade nao reconhecida

**Sintoma**

- Operacao de CRUD falha com erro de mapeamento.
- O Janus nao encontra a tabela correspondente.

**Causa provavel**

- A classe nao foi registrada no bloco initialization.

**Como resolver**

1. Abra a unit da entidade.
2. Confirme a presenca do registro abaixo:

```delphi
initialization
  TRegisterClass.RegisterEntity(Tclient);
```

## SQL incompativel com o banco

**Sintoma**

- Erro de sintaxe SQL em runtime.
- Comandos gerados nao respeitam o dialeto do banco.

**Causa provavel**

- Driver escolhido na factory nao corresponde ao banco em uso.

**Como resolver**

1. Revise o driver informado em TFactoryFireDAC.Create.
2. Confirme se o enum (dnSQLite, dnMySQL, etc.) esta correto para o ambiente.
3. Verifique se a unit `Janus.DML.Generator.<Driver>` foi incluida no projeto.

## ELazyLoadException ao acessar relacionamento

**Sintoma**

- Acesso a `MinhaEntidade.Relacao.Value` falha com mensagem indicando sessao destruida.
- O erro aparece depois de fechar o container, manager ou sessao.

**Causa provavel**

- O relacionamento lazy foi acessado depois que o contexto de persistencia ja tinha sido encerrado.

**Como resolver**

1. Garanta que o primeiro acesso a `.Value` ocorra enquanto a sessao ainda estiver ativa.
2. Evite guardar a entidade para uso posterior fora do ciclo de vida do container.
3. Em DataSet e REST, reutilize o fluxo padrao do framework para que a reinjecao do proxy ocorra automaticamente.

## Relacionamento lazy nao atualiza apos navegar no DataSet

**Sintoma**

- A tela muda de registro, mas a associacao lazy continua mostrando dados da linha anterior.

**Causa provavel**

- O objeto foi reutilizado fora do fluxo do `TManagerDataSet` ou o acesso foi feito em momento fora da navegacao controlada pelo framework.

**Como resolver**

1. Abra e navegue o DataSet pelo fluxo normal do manager/container.
2. Evite manter referencias antigas da mesma entidade entre trocas de registro.
3. Use o monitor SQL para confirmar a nova carga quando a PK mudar.

## Erro de bind em INSERT/UPDATE

**Sintoma**

- Excecao relacionada a parametros na execucao.

**Causa provavel**

- Diferenca entre colunas mapeadas e parametros esperados no comando.

**Como resolver**

1. Verifique se todas as propriedades tem atributo Column consistente.
2. Revise restricoes como NotNull e campos obrigatorios.
3. Confirme tipos Delphi compativeis com o tipo do banco.

## Tabela ou coluna nao encontrada

**Sintoma**

- Mensagem de erro indicando tabela/coluna inexistente.

**Causa provavel**

- Divergencia entre nome no atributo e nome real no banco.

**Como resolver**

1. Compare Table e Column com o esquema real.
2. Ajuste o mapeamento na entidade.
3. Recompile e execute novamente.

## Erro E2003: Undeclared identifier `Supports` no smoke

**Sintoma**

- A compilacao da suite smoke falha com `E2003 Undeclared identifier: 'Supports'`.

**Causa provavel**

- Unit necessaria para resolver `Supports` ausente no `uses` do modulo de teste.

**Como resolver**

1. Revise o `uses` da unit que referencia `Supports`.
2. Inclua `SysUtils` quando necessario.
3. Recompile `Test/Delphi/JanusSmoke.dpr`.

## Erro F2613: Unit `SysUtils` not found

**Sintoma**

- O gate de compilacao falha com `F2613 Unit 'SysUtils' not found`.

**Causa provavel**

- Ambiente Delphi nao carregado corretamente no script de build.

**Como resolver**

1. Reexecute o fluxo oficial de build/smoke do projeto.
2. Garanta que o ambiente do compilador Delphi esteja inicializado antes da compilacao.
3. Valide novamente o `JanusSmoke.dpr` apos ajustar o ambiente.
