---
title: Referencia de Configuracao
displayed_sidebar: janusSidebar
---

Esta pagina reune os principais pontos de configuracao para operar o Janus em projetos Delphi.

Versao de referencia deste manual: `v2.19.14`.

As releases de `v2.19.5` ate `v2.19.14` nao alteraram o contrato de configuracao de uso para quem opera o framework no dia a dia.

## Comandos de instalacao

```bash
boss install "https://github.com/ModernDelphiWorks/Janus"
```

## Dependencias do ecossistema

| Dependencia | Finalidade | Origem |
|-------------|------------|--------|
| MetaDbDiff | Mapeamento e metadata ORM | Resolvida via Boss |
| DataEngine | Abstracao de conexao | Resolvida via Boss |
| FluentSQL | Geracao de SQL por dialeto | Resolvida via Boss |
| JsonFlow | Serializacao JSON | Resolvida via Boss |

## Configuracoes operacionais

| Item | Onde configurar | Exemplo | Observacoes |
|------|-----------------|---------|-------------|
| Driver de banco | Factory de conexao | dnSQLite, dnMySQL | Deve refletir o banco real em uso |
| Unit do gerador DML | `uses` do projeto ou modulo de inicializacao | `Janus.DML.Generator.SQLite` | Necessaria para registrar automaticamente o dialeto SQL do banco |
| Conexao ativa | Componente FireDAC/DataEngine | FDConnection1 | Validar credenciais e disponibilidade antes de abrir container |
| Registro de entidade | Bloco initialization da unit | TRegisterClass.RegisterEntity(Tclient) | Obrigatorio para reconhecimento do mapeamento |
| Persistencia de alteracoes | Evento de acao da tela ou servico | ApplyUpdates(0) | Retorno deve ser tratado para feedback ao usuario |
| Ciclo de vida do lazy | Escopo da sessao/container | acesso a `Lazy<T>.Value` com sessao viva | Fechar a sessao antes do primeiro acesso pode gerar `ELazyLoadException` |
| Monitor SQL | Apos criar conexao | SetCommandMonitor(TCommandMonitor.GetInstance) | Recomendado em homologacao e troubleshooting |

## Seguranca e dados sensiveis

- Nao versionar credenciais de banco em codigo-fonte.
- Use placeholders ao documentar configuracoes sensiveis.

```text
DB_HOST=<YOUR_VALUE>
DB_USER=<YOUR_VALUE>
DB_PASSWORD=<YOUR_VALUE>
```

## Checklist de configuracao inicial

1. Instalar Janus e dependencias via Boss.
2. Configurar conexao de banco no ambiente.
3. Definir driver DML correto na factory.
4. Incluir a unit `Janus.DML.Generator.<Driver>` correspondente no projeto.
5. Registrar todas as entidades utilizadas.
6. Validar abertura de container e persistencia com teste simples.
7. Se usar `[Lazy]`, validar o primeiro acesso a `.Value` antes de encerrar a sessao.
8. Se seu fluxo inclui smoke/local CI, compilar `Test/Delphi/JanusSmoke.dpr` para detectar problemas de ambiente antes de publicar.
