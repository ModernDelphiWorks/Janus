# Censo de cobertura de compilação — Janus

**Isto é medição, não conserto.** Nada em `Source/`, `.dpr` ou `.dproj` foi alterado.

| | |
|---|---|
| **Commit medido** | `0546a51b42eb97d3f882c9725ac98288e4420d78` (`0546a51`, merge do PR #336) |
| **Data da medição** | 12 ago 2026 |
| **Compilador** | RAD Studio 37.0, `Win32` / `Debug` |
| **Pin obrigatório** | FluentSQL em `..\..\..\_wt-fluentsql-pin265\Source\{Core,Drivers}` |
| **Script que regenera tudo** | `Test/Delphi/Tools/compile-coverage-census.ps1` |
| **Matriz completa 136 × 7** | `Test/Delphi/Tools/census-matrix-0546a51.csv` |

Regenerar:

```
powershell -NoProfile -File Test\Delphi\Tools\compile-coverage-census.ps1
```

---

## A pergunta

Para cada unit de `Source/`, **quais dos sete projetos de `Test/Delphi` a compilam** — e
quantas não são compiladas por **nenhum**.

Isto é anterior a "tem teste". Uma unit que **nenhum projeto compila** pode estar quebrada
desde sempre e a suíte continua verde. Foi assim que a issue **#323** descobriu
`Janus.Client.DataSnap.pas` e `Janus.Client.WS.pas`. O censo mede o tamanho disso.

---

## Os cinco números

| | com `Source/External/` | sem `Source/External/` |
|---|---:|---:|
| **1. units `.pas` em `Source/`** | **136** | **134** |
| **2. compiladas por ≥ 1 projeto** | **105** | **105** |
| **3. compiladas por NENHUM** | **31** | **29** |
| **4. compiladas por EXATAMENTE 1 projeto** (frágeis) | **44** | **44** |
| divergência entre as duas medidas (`.map` × `.dcu`) | 13 | 13 |

Comando que produz (1):

```
Get-ChildItem <repo>\Source -Recurse -Filter *.pas | Measure-Object
```

(2), (3) e (4) saem do script acima, seção `=== NUMEROS ===`.

### O que foi excluído da contagem, e por quê

- **`Source/Dependencies/` — não existe em `0546a51`.** Não foi "excluído": não está lá.
  Os sete `.dproj` ainda listam **26** caminhos `..\..\Source\Dependencies\...` em
  `DCC_UnitSearchPath` (contados em `Janus.Tests.Units.dproj`: 65 entradas, 26 sob
  `Source\Dependencies`, **30 inexistentes em disco**), todos apontando para diretório
  ausente. É exatamente por isso que a **poda** do script é *load-bearing* (ver Método).
  Verificar: `Test-Path <repo>\Source\Dependencies` → `False`.
- **`Source/External/SQLite3/` — existe, com 2 units de terceiro** (`SQLite3.pas`,
  `SQLiteTable3.pas`, wrapper vendorizado do SQLite). Estão **na** contagem de 136 e são
  **ambas não cobertas**; a coluna "sem External" mostra o recorte que exclui as duas. Nenhum
  outro número muda, porque nenhuma das duas é compilada por projeto algum.

### Cobertura por projeto (units de `Source/`)

| projeto | units de `Source/` que compila |
|---|---:|
| `Janus.Tests.Units` | 76 |
| `Janus.Tests.RESTMARS` | 46 |
| `Janus.Tests.RESTHorse` | 45 |
| `Janus.Tests.RESTfulDriver` | 39 |
| `Janus.Tests.RESTOracle` | 35 |
| `Janus.Tests.RESTWiRL` | 12 |
| `Janus.Tests.LiveBindings` | **3** |

`Janus.Tests.LiveBindings` compila **três** units de `Source/` — `Janus.Binder`,
`Janus.Binder.Attributes`, `Janus.Binder.Resolver` — e nada mais do framework. É o projeto
mais estreito dos sete por uma ordem de grandeza.

---

## Método — e por que o `.map` **não** serve sozinho

Foram coletadas **duas** medidas independentes, por projeto, no mesmo build
(`/p:DCC_MapFile=3`):

- **(a) MAP** — os módulos citados como `M=<unit>` no `.map` gerado.
- **(b) DCU** — os `.dcu` escritos no `DCC_DcuOutput` **próprio** do projeto
  (`.\$(Platform)\$(Config)\$(MSBuildProjectName)`, desde o PR #272).

### A divergência, e o que ela é

MAP e DCU discordam em **13** units. Em **todas as 13** o sinal é o mesmo: `NMap=0`,
`NDcu>0`. E o teste estrutural fecha: **MAP é subconjunto ESTRITO de DCU nos sete projetos**
— `MAP-sem-DCU = 0` em cada um deles, sem exceção. Ou seja, o `.map` nunca vê algo que o
`.dcu` não veja; ele apenas **deixa de ver**.

O motivo é o formato: o `.map` só nomeia um módulo quando esse módulo **emite segmento**.
Não emitem:

- units **só-constante** — `Janus.Core.Consts`, `Janus.DataSet.Consts`, `Janus.Client.Consts`
  (`implementation` com 4 caracteres depois dela);
- units **só-interface** — `Janus.Container.DataSet.Interfaces`;
- units **integralmente genéricas** — `Janus.Container.ObjectSet`, `Janus.Command.Executor`,
  `Janus.ObjectSet.Adapter`, `Janus.Session.ObjectSet`, `Janus.RestDataSet.Adapter`,
  `Janus.RestObjectSet.Adapter`, `Janus.Container.ClientDataSet`, `Janus.Container.DataSet`,
  `Janus.Container.FDMemTable`. O código do genérico sai no módulo que o **instancia**, não
  no que o declara.

Consequência prática: **se o censo tivesse sido feito só pelo `.map`, ele acusaria 44 units
não cobertas em vez de 31** — 13 falsos positivos, e entre eles o `Janus.Container.ObjectSet`,
que é o container central do ORM.

**A medida autoritativa é a (b), DCU.** A (a) fica no script e no CSV (colunas `NMap`/`NDcu`)
justamente para que essa divergência continue sendo **conferida**, e não escolhida.

### Riscos da medida DCU, e como foram fechados

| risco | controle |
|---|---|
| `.dcu` sobrando de medição anterior contaria como cobertura | o script **apaga** `Win32\Debug\<Projeto>\` e o `.map` **antes de cada build** |
| um `.dcu` de outro projeto contaminar a contagem | cada `.dproj` carimba em subdiretório próprio (PR #272) e o script **nunca** passa `/p:DCC_DcuOutput` — a linha de comando venceria o `.dproj` e recolidiria os sete em silêncio |
| casamento por *basename* atribuir à unit errada | **verificado**: zero basenames duplicados dentro de `Source/`, e zero basenames de `Source/` que também existam fora de `Source/` na árvore. O script **aborta** se aparecer duplicata |
| build quebrado gerar número falso | os sete builds saíram com `exit=0`; o script **aborta** se algum falhar |

Comando da verificação de colisão de nomes:

```powershell
$src=@{}; Get-ChildItem <repo>\Source -Recurse -Filter *.pas | % { $src[$_.BaseName.ToLower()]=1 }
Get-ChildItem <repo> -Recurse -Filter *.pas |
  ? { $_.FullName -notlike "<repo>\Source\*" -and $src.ContainsKey($_.BaseName.ToLower()) }
# saída vazia
```

### Controles — o censo não vale sem eles

- **Positivo.** `Janus.Bind` aparece em **5 dos 7** (`Units`, `RESTfulDriver`, `RESTHorse`,
  `RESTMARS`, `RESTOracle`), e **MAP e DCU concordam** nos cinco.
- **Negativo.** `Janus.Client.DataSnap` e `Janus.Client.WS` aparecem em **ZERO dos 7**, tanto
  por MAP quanto por DCU. Reproduz a #323 pelo caminho do compilador, sem *tripwire*.
  ⚠️ A frente da #323 está em voo e vai mudar isso — este número vale para `0546a51`.

Ambos os controles estão **embutidos no script**, que emite `Write-Warning` e falha se
quebrarem.

### Armadilhas da receita de build (todas verificadas nesta medição)

- `/p:"DCC_UnitSearchPath="` é **global** e **suprime** a lista do `.dproj`. É preciso ler
  **todos** os nós `DCC_UnitSearchPath` e concatená-los na ordem. **Quatro dos sete têm
  DOIS** (`LiveBindings`, `RESTfulDriver`, `RESTMARS`, `RESTWiRL`); o segundo prepende
  `$(BDSLIB)\$(Platform)\{debug,release}`. `RESTOracle` tem um único nó, mas carrega uma
  entrada a mais que os outros: `..\..\Examples\Delphi\RESTful\Horse\Oracle\models`.
- **A poda é *load-bearing*.** Depois de dedup + `Test-Path` (nunca regex), os sete ficam
  entre **1226 e 1659 chars**. Sem a poda o `RESTWiRL` passa de 3200 e morre com
  `MSB6003 filename or extension is too long` — parece defeito do repo e não é.
- Os caminhos relativos **não** são absolutizados (os targets repetem a lista em
  `-U`/`-I`/`-O`/`-R`); `$(MARSDIR)` e `$(WIRLDIR)` são resolvidos com `String.Replace`.

---

## As 31 não compiladas por nenhum dos sete — **o produto principal**

Ordenadas por **gravidade**: primeiro o que chega ao consumidor.

### Nível 1 — vão para dentro do que é distribuído (7 units)

Estas entram no `library JanusFramework` — `Projects/Janus DLL Framework/JanusFramework.dpr`,
cláusula `uses` direta:

| unit | também é |
|---|---|
| `Source/Core/Janus.DML.Generator.InterBase.pas` | injetada no projeto do usuário pelo pacote de design-time |
| `Source/Core/Janus.DML.Generator.MongoDB.pas` | injetada no projeto do usuário pelo pacote de design-time |
| `Source/Core/Janus.DML.Generator.MySQL.pas` | injetada no projeto do usuário pelo pacote de design-time |
| `Source/Core/Janus.DML.Generator.AbsoluteDB.pas` | nomeada por `Examples/Delphi/Data/AbsoluteDB` |
| `Source/Core/Janus.DML.Generator.NexusDB.pas` | nomeada por `Examples/Delphi/Data/NexusDB` |
| `Source/Core/Janus.DML.Generator.ElevateDB.pas` | — |
| `Source/Core/Janus.DML.Generator.NoSQL.pas` | usada por `Janus.DML.Generator.MongoDB` |

"Injetada no projeto do usuário" é literal: `Components/Source/Janus.Link.Reg.pas` — que vai
no pacote de design-time `dclJanusDriversLinks.dpk` — tem `RequiresUnits` chamando
`Proc('Janus.DML.Generator.MongoDB')` (L110), `Proc('Janus.DML.Generator.MySQL')` (L124) e
`Proc('Janus.DML.Generator.InterBase')` (L138). O IDE escreve esses nomes na cláusula `uses`
do projeto **do cliente**. São três units que o Janus manda o cliente compilar e que o Janus
não compila.

> **Achado lateral, fora do censo:** `Janus.Link.Reg.pas:152` chama
> `Proc('Janus.DML.Generator.sqldirect')`. Essa unit **não existe** — não há
> `Janus.DML.Generator.SQLDirect.pas` em lugar nenhum do repositório
> (`Get-ChildItem <repo> -Recurse -Filter "Janus.DML.Generator.SQLDirect.pas"` → 0). O
> editor de design-time do driver SQLDirect injeta um `uses` que não compila no projeto do
> cliente. Não virou issue.

### Nível 2 — nomeadas por `Examples/` (o consumidor as compila ao abrir o exemplo)

**Família DataSnap / DMVC / WebService do cliente REST — 9 units, os três drivers inteiros:**

| unit | quem a nomeia |
|---|---|
| `Source/RESTful/Client/Janus.Client.DataSnap.pas` | `Examples/.../Datasnap/Client/JanusFireDAC.dpr`, `uMainFormORM.pas` |
| `Source/RESTful/Client/Janus.Client.RestDataSnap.Factory.pas` | via `Janus.Client.DataSnap` |
| `Source/RESTful/Client/Janus.Client.RestDriver.DataSnap.pas` | via a fábrica acima |
| `Source/RESTful/Client/Janus.Client.DMVC.pas` | `Examples/.../DelphiMVC/Client/JanusClient.dpr` |
| `Source/RESTful/Client/Janus.Client.RestDMVC.Factory.pas` | `Examples/.../DelphiMVC/Client/JanusClient.dpr` |
| `Source/RESTful/Client/Janus.Client.RestDriver.DMVC.pas` | `Examples/.../DelphiMVC/Client/JanusClient.dpr` |
| `Source/RESTful/Client/Janus.Client.WS.pas` | `Examples/.../WebService/uPrincipal.pas` |
| `Source/RESTful/Client/Janus.Client.RestWS.Factory.pas` | via `Janus.Client.WS` |
| `Source/RESTful/Client/Janus.Client.RestDriver.WS.pas` | via a fábrica acima |

São as duas da #323 (`DataSnap`, `WS`) **mais o DMVC**, cada uma com sua fábrica e seu driver.
O comentário em `Test/Delphi/Unit/RESTful/Test.Janus.Client.RestExceptionFields.pas` já
registrava o do DMVC como buraco conhecido — o censo confirma e completa a família.

**Lado servidor — 6 units:**

| unit | quem a nomeia |
|---|---|
| `Source/RESTful/Server/Janus.Server.DataSnap.pas` | `Examples/.../Datasnap/Server/JanusServer.dpr` |
| `Source/RESTful/Server/Janus.Server.Resource.DataSnap.pas` | idem |
| `Source/RESTful/Server/Janus.Server.DMVC.pas` | `Examples/.../DelphiMVC/Server/JanusServer.dpr` |
| `Source/RESTful/Server/Janus.Server.Resource.DMVC.pas` | idem |
| `Source/RESTful/Server/Janus.Server.WiRL.pas` | `Examples/.../WiRL/Server/JanusServer.dpr` |
| `Source/RESTful/Server/Janus.Server.Resource.WiRL.pas` | idem |

O WiRL merece nota: `Janus.Tests.RESTWiRL` **existe** e compila 12 units — mas só o lado
**cliente**. O servidor WiRL (`Janus.Server.WiRL`, `Janus.Server.Resource.WiRL`) não é
compilado por nenhum dos sete.

**Outras — 4 units:**

| unit | quem a nomeia |
|---|---|
| `Source/Monitor/Janus.Form.Monitor.pas` | **38 arquivos** de `Examples/` (é o monitor de SQL que quase todo exemplo abre) |
| `Source/Metadata/Janus.ModelDB.Compare.pas` | `Examples/Delphi/Metadata/FireDAC/Firemonkey/uPrincipal.pas` |
| `Source/External/SQLite3/SQLite3.pas` | `Examples/Delphi/Data/ADO*/uMainFormORM.pas` (terceiro) |
| `Source/External/SQLite3/SQLiteTable3.pas` | `Examples/Delphi/Data/SQLite Native*/uMainFormORM.pas` (terceiro) |

### Nível 3 — nenhuma referência em lugar nenhum do repositório (5 units)

Varredura de 540 arquivos `.pas`/`.dpr`/`.dpk` da worktree, excluindo o próprio arquivo:

| unit | situação |
|---|---|
| `Source/Middleware-Horse/Horse.Janus.pas` | **0 referências.** É o middleware Horse — superfície pública de integração do framework, e nada no repo o toca |
| `Source/Core/Janus.DML.Generator.Firebird3.pas` | **0 referências.** O único gerador DML fora até do `JanusFramework.dpr` |
| `Source/Livebindings/Janus.OneToMany.pas` | **0 referências.** Vive ao lado das 3 units que o `LiveBindings` compila e não é uma delas |
| `Source/RESTful/Server/Janus.Server.Swagger.Horse.pas` | **0 referências** *e* corpo inteiro sob `{$IFDEF JANUS_SWAGGER}` — ver ambiguidades |
| `Source/Metadata/Janus.Metadata.Classe.Factory.pas` | **0 referências reais.** A única citação (`Test.Janus.Metadata.Compare.pas`) está **dentro de comentário**: o fixture foi retargetado para `MetaDbDiff.Metadata.Model.Factory` e a classe daqui é descrita ali como "thin, deprecated, empty subclass" |

Duas citações levantadas na varredura foram investigadas antes de virarem número e **caíram**:
a de `Janus.Client.DMVC` em `Test.Janus.Client.RestExceptionFields.pas` e a de
`Janus.Metadata.Classe.Factory` em `Test.Janus.Metadata.Compare.pas` — **ambas em
comentário**, nenhuma em cláusula `uses`. Nenhuma das duas units é compilada.

---

## Ambiguidades — `{$IFDEF}` e cobertura de linha

**Regra usada:** unit que entra só por `{$IFDEF}` desligado conta como **não compilada**.
Nenhuma das 31 acima está nessa situação por causa de `IFDEF` — as 31 estão fora porque
**nenhum `.dpr` de teste as alcança**. O caso de `IFDEF` é outro, e é este:

- **`JANUS_SWAGGER` não é definido em `.dproj` nenhum do repositório.**
  `Janus.Server.Swagger.Horse.pas` tem o corpo inteiro dentro de `{$IFDEF JANUS_SWAGGER}`,
  com um `{$ELSE} interface implementation {$ENDIF}` que a reduz a uma unit **vazia**. Logo,
  o conteúdo real dessa unit **não compila em configuração nenhuma que exista no repo** —
  nem nos sete testes, nem nos `Examples`, nem nos pacotes. É pior que "não coberta": é
  inatingível.
- **`DRIVERRESTFUL`** — `Source/Janus.inc:52` a entrega **comentada**; dos sete, só
  `Janus.Tests.RESTfulDriver` a liga. Os blocos sob esse `IFDEF` em
  `Janus.Manager.DataSet`, `Janus.Manager.ObjectSet`, `Janus.Session.RESTful`,
  `Janus.RestObjectSet.Adapter`, `Janus.ObjectSet.Base.Adapter` e `Janus.Session.Abstract`
  só compilam nesse projeto.
- **`USECLIENTDATASET`** — nunca ligada nos sete (`Janus.inc:53` comentada), o que mantém
  `USEFDMEMTABLE` ligada. O ramo ClientDataSet de `Janus.Manager.DataSet` (L102, L126, L543)
  **nunca compila nos testes**; é ligado só por `.dproj` de `Examples`.
- **`MONITORRESTFULCLIENT`** — nunca ligada nos sete; o bloco de `Janus.Form.Monitor.pas:38`
  nunca compila (a unit inteira já não compila, de todo modo).

**Não medido:** isto é um censo de **unit**, não de **linha**. Uma unit marcada "coberta"
pode ter trechos inteiros sob `IFDEF` que nenhum dos sete compila — os quatro símbolos acima
são os que existem. Quantificar isso exigiria compilar cada projeto em cada combinação de
símbolos, e **não foi feito**.

---

## As 44 frágeis — compiladas por **um só** projeto

Se aquele projeto mudar de forma, elas somem do build sem que nada fique vermelho. Lista
nominal completa na seção `=== COMPILADAS POR UM SO PROJETO ===` da saída do script e na
coluna `NDcu=1` do CSV. Concentração por dono:

| único projeto que a compila | quantas |
|---|---:|
| `Janus.Tests.Units` | 27 |
| `Janus.Tests.RESTfulDriver` | 5 |
| `Janus.Tests.RESTMARS` | 5 |
| `Janus.Tests.LiveBindings` | 3 |
| `Janus.Tests.RESTWiRL` | 3 |
| `Janus.Tests.RESTOracle` | 1 |
| `Janus.Tests.RESTHorse` | **0** |

(soma 44. `Janus.Tests.RESTHorse` compila 45 units de `Source/` e não é dono exclusivo de
nenhuma — tudo que ele compila, outro projeto também compila.)

Duas leituras que valem:

- **`Janus.Tests.RESTOracle` é o único projeto que compila `Janus.DML.Generator.Oracle.pas`.**
  Este censo mediu que ele **builda** (`exit=0`); que ele tenha 12 erros de **execução** é
  informação da campanha, **não medida aqui**. De um jeito ou de outro: se alguém desligar
  esse projeto, o gerador Oracle deixa de ser compilado por qualquer coisa e nada acusa.
- **As 3 units de LiveBindings são as 3 que o `LiveBindings` compila.** O projeto e o módulo
  são um só. Ele é simultaneamente o dono exclusivo de tudo que compila e o mais estreito
  dos sete.

---

## Fora de `Source/`

### `Components/Source/` — **zero** compiladas por qualquer um dos sete

28 arquivos `.pas` (19 próprios + 9 de `MongoWire`, terceiro). **Nenhum** deles produz `.dcu`
em nenhum dos sete projetos. A razão é direta: **nenhum dos sete `DCC_UnitSearchPath` cita
`Components`** — nem antes nem depois da poda.

```powershell
Get-ChildItem <repo>\Test\Delphi\Win32\Debug\_census -Filter *.searchpath.txt |
  % { (Get-Content $_.FullName -Raw) -split ';' | ? { $_ -like '*Components*' } }
# saída vazia, nos sete
```

Isto é o pior recorte do censo em razão consumidor/cobertura: são **exatamente** as units que
o cliente instala no IDE. `JanusDriversLinks.dpk` embarca os 9 `Janus.Driver.Link.*`;
`dclJanusManagerObjectSet.dpk`, `dclJanusManagerClientDataSet.dpk` e
`dclJanusManagerFDMemTable.dpk` embarcam os `Janus.DB.Manager.*` e os `Janus.Manager.*`;
`dclJanusDriversLinks.dpk` embarca `Janus.Link.Reg`. **100% shipado, 0% compilado pela
suíte.**

### `Examples/` — 12 de 155 compiladas

| via | quantas | quais |
|---|---:|---|
| `in '..\..\Examples\...'` explícito em `Janus.Tests.Units.dpr` | 8 | `Data\Models\Janus.Model.{Client,Detail,Lookup,Master}.pas` e `Data\Object Lazy\Model.{Atendimento,Exame,Procedimento,Setor}.pas` |
| `DCC_UnitSearchPath` de `Janus.Tests.RESTOracle` | 4 | `RESTful\Horse\Oracle\models\Janus.Oracle.Model.{Cliente,Pedido,PedidosCompletos,Produto}.pas` |

As **143** restantes — inclusive todo `uMainFormORM.pas`, todo `Principal.pas` e os `.dpr`
dos exemplos — não são compiladas por nenhum dos sete. Existe o workflow
`.github/workflows/examples.yml`; **este censo não o executou e não afirma nada sobre ele.**

> Atenção ao método aqui: casar `.dcu` com arquivo de `Examples/` **por basename** dá 57
> falsos positivos, porque `Janus.Model.Client.pas` existe em 12 diretórios diferentes. A
> atribuição acima é por **caminho**, lida das cláusulas `in '...'` dos `.dpr` e do único
> caminho `Examples` presente em search path. Dentro de `Source/` o casamento por basename é
> seguro — foi verificado que não há duplicata nem colisão (ver Método).

---

## O que este documento **não** mediu

- **Cobertura de linha / de teste.** "Compilada" ≠ "exercitada". Uma unit compilada pode não
  ter uma única asserção.
- **Combinações de `{$IFDEF}`.** Medido em `Debug`/`Win32` com os símbolos que os sete
  `.dproj` já carregam. Trechos sob `DRIVERRESTFUL`, `USECLIENTDATASET`,
  `MONITORRESTFULCLIENT` e `JANUS_SWAGGER` não foram varridos combinatoriamente.
- **Plataformas além de `Win32`** e configuração `Release`.
- **Os workflows do CI.** `.github/workflows/{tests,examples}.yml` não foram executados; o
  censo mede os sete `.dproj` diretamente. Se o CI compilar algo a mais, este censo não vê.
- **Se os `Examples/` e os pacotes de `Components/Packages/` compilam hoje.** O censo diz que
  a suíte não os compila; não diz que eles quebram.
- **`Projects/Janus DLL Framework/JanusFramework.dpr` builda?** Não medido — só foi lida a
  cláusula `uses` dele, para saber o que é distribuído.
