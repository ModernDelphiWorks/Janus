---
title: Introducao
displayed_sidebar: janusSidebar
---

O Janus e um framework ORM para Delphi que transforma classes em entidades persistidas no banco, com geracao automatica de comandos SQL para diferentes drivers.

Para quem usa o framework no dia a dia, isso significa menos SQL manual, menos codigo repetitivo de persistencia e uma mesma abordagem de uso em cenarios com DataSet visual, listas orientadas a objetos e integracao REST.

## O que o Janus resolve

- Reduz codigo repetitivo de CRUD.
- Centraliza mapeamento com atributos na propria classe de dominio.
- Permite trocar banco suportado com minimo impacto no codigo da aplicacao.
- Mantem integracao natural com DataSet para telas e rotinas legadas.

## Publico-alvo

- Desenvolvedor Delphi em sistemas VCL/FMX.
- Equipe que mantem aplicacoes com multiplos bancos suportados.
- Projetos que precisam de persistencia OO com menor acoplamento ao SQL nativo.

## Conceitos essenciais

- Entidade mapeada: classe Delphi com atributos como Entity, Table, PrimaryKey e Column.
- Registro de entidade: etapa obrigatoria no bloco initialization para o runtime reconhecer o mapeamento.
- Container DataSet/ObjectSet: camada de operacao de dados para leitura, edicao e persistencia.
- Driver DML: componente que traduz operacoes para o dialeto do banco selecionado.
- Lazy transparente: associacoes anotadas com `[Lazy]` podem carregar no primeiro acesso, sem exigir `LoadLazy` manual em fluxos suportados.

## Fluxo de uso no dia a dia

1. Modelar entidade Delphi com atributos.
2. Registrar entidade no initialization da unit.
3. Configurar conexao via DataEngine Factory.
4. Instanciar container e abrir os dados.
5. Aplicar alteracoes com ApplyUpdates.
