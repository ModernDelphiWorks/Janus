# Relatório Arquitetural: Janus DLL Framework vs Modos de Uso do ORM

**Data:** 2026-04-03  
**Escopo:** Análise das 4 formas de uso do Janus ORM nativo e avaliação de cobertura pela DLL Bridge

---

## 1. Os 4 modos de uso do Janus ORM (Delphi nativo)

O Janus ORM oferece 4 formas de inicialização, organizadas em 2 eixos:

| | Container Direto (simples) | Manager (orquestrador) |
|---|---|---|
| **DataSet (visual)** | Modo 1A | Modo 2A |
| **ObjectSet (objeto puro)** | Modo 1B | Modo 2B |

---

### Modo 1A — Container Direto + DataSet

Uso mais básico. Um `TContainerFDMemTable<T>` (ou `TContainerClientDataSet<T>`) é criado diretamente, ligado a um `TDataSet` visual.

```delphi
oConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);

oContainerMaster := TContainerFDMemTable<Tmaster>.Create(oConn, FDMaster, 3);
oContainerDetail := TContainerFDMemTable<Tdetail>.Create(oConn, FDDetail, oContainerMaster.This);
oContainerClient := TContainerFDMemTable<Tclient>.Create(oConn, FDClient, oContainerMaster.This);
oContainerLookup := TContainerFDMemTable<Tlookup>.Create(oConn, FDLookup);

oContainerDetail.AddLookupField('fieldname', 'lookup_id',
  oContainerLookup.This, 'lookup_id', 'lookup_description', 'Descrição Lookup');

oContainerMaster.OpenWhere('', 'description desc, master_id asc');
```

**Dependências internas:**
- `IDBConnection` (conexão)
- `TDataSet` (TFDMemTable ou TClientDataSet) — componente visual
- `TDataSetBaseAdapter<T>` — adaptador RTTI que sincroniza objeto ↔ dataset row
- `TDataSetEvents` — eventos BeforeScroll, AfterOpen, etc.
- RTTI completa (atributos `[Entity]`, `[Table]`, `[Column]`, etc.)
- Master/Detail via `oContainerMaster.This` (referência ao adapter)
- Lookups via `AddLookupField`

**Características:**
- Dados aparecem direto em grids (DBGrid, TDataSource)
- Edição é via Post/Edit/Cancel do TDataSet
- Persistência via `ApplyUpdates`
- Paginação via `NextPacket` / `AutoNextPacket`
- Suporte a hierarquia master → detail com cascade

---

### Modo 1B — Container Direto + ObjectSet

Sem componente visual. Trabalha com `TObjectList<T>` diretamente.

```delphi
oConn := TFactoryFireDAC.Create(FDConnection1, dnSQLite);
oConn.SetCommandMonitor(TCommandMonitor.GetInstance);

oMaster := TContainerObjectSet<Tmaster>.Create(oConn, 3);
oMasterList := oMaster.Find;
```

**Dependências internas:**
- `IDBConnection` (conexão)
- `TObjectSetAdapter<T>` — adaptador RTTI que executa CRUD via SQL gerado
- `TSessionObjectSet<T>` — sessão que gera comandos SQL por banco
- RTTI completa
- Middleware callbacks (BeforeInsert, AfterDelete, etc.)
- Object state tracking (ModifiedFields)

**Características:**
- Retorna `TObjectList<T>` — lista tipada
- CRUD direto: `Insert(AObject)`, `Update(AObject)`, `Delete(AObject)`
- Cascade automático (OneToOne, OneToMany)
- Lazy loading via `LoadLazy`
- Paginação via `NextPacket`

---

### Modo 2A — TManagerDataSet (orquestrador visual)

Versão mais moderna para DataSet. Um único Manager coordena múltiplos adapters com API fluente.

```delphi
oConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL);
oConn.SetCommandMonitor(TCommandMonitor.GetInstance);

oManager := TManagerDataSet.Create(oConn);
oManager.AddAdapter<Tmaster>(FDMaster, 3)
        .AddAdapter<Tdetail, Tmaster>(FDDetail)
        .AddAdapter<Tclient, Tmaster>(FDClient)
        .AddAdapter<Tlookup>(FDLookup)
        .AddLookupField<Tdetail, Tlookup>('fieldname',
          'lookup_id', 'lookup_id', 'lookup_description', 'Descrição Lookup');
oManager.Open<Tmaster>;
```

**Dependências internas (adicionais ao Modo 1A):**
- `TManagerDataSet` — orquestrador com dicionário interno de adapters
- `TDictionary<String, TObject>` — registro de adapters por tipo
- Resolução de master/detail via generics: `AddAdapter<Tdetail, Tmaster>`
- `IMDConnection` — abstração que pode ser IDBConnection ou IRESTConnection

**Características:**
- API fluente: encadeia AddAdapter
- Gerencia múltiplos DataSets em hierarquia
- Master/Detail implícito via dois parâmetros genérics
- Open/Close/ApplyUpdates centralizados por tipo

---

### Modo 2B — TManagerObjectSet (orquestrador de objetos)

Versão mais moderna para ObjectSet. Manager coordena múltiplos repositórios.

```delphi
FConn := TFactoryFireDAC.Create(FDConnection1, dnMySQL, TCommandMonitor.GetInstance);
FManager := TManagerObjectSet.Create(FConn);
FManager.OwnerNestedList := True;
FManager
  .AddAdapter<Tmaster>(3)
  .Find<Tmaster>;
```

**Dependências internas (adicionais ao Modo 1B):**
- `TManagerObjectSet` — orquestrador com dicionário de repositórios
- `TRepositoryList` (TObjectDictionary) — registro de adapters
- Navegação stateful: `Current<T>`, `First<T>`, `Next<T>`, `Eof<T>`
- Dois modos de operação via `OwnerNestedList`:
  - `True` → Manager mantém estado (Current + Index), CRUD opera sobre Current
  - `False` → Stateless, CRUD recebe objeto como parâmetro

**Características:**
- API fluente
- Navegação sequencial (emula cursor)
- Gerencia nested lists (master/detail em memória)
- Change tracking via `ModifiedFields`
- Cascade automático

---

## 2. O que a DLL expõe hoje

### Funções exportadas

| Export | Retorno | Finalidade |
|---|---|---|
| `RegisterModels` | `LongBool` | Registra modelos pré-compilados (Strategy 1) |
| `ConnectSQLite` | `IJanusConnection` | Conexão SQLite |
| `ConnectFirebird` | `IJanusConnection` | Conexão Firebird |
| `ConnectMySQL` | `IJanusConnection` | Conexão MySQL |
| `ConnectPostgreSQL` | `IJanusConnection` | Conexão PostgreSQL |
| `ConnectMSSQL` | `IJanusConnection` | Conexão MSSQL |
| `ConnectOracle` | `IJanusConnection` | Conexão Oracle |
| `CreateObjectSet` | `IJanusObjectSet` | CRUD (Strategy 1 ou 2) |
| `CreateQuery` | `IJanusQuery` | Queries com filtros |
| `CreateEntityBuilder` | `IJanusEntityBuilder` | Registro programático (Strategy 2) |
| `NewManagerObjectSet` | `TManagerObjectSet` | **Exportado mas inutilizável** (ver abaixo) |

### Interfaces COM-safe

| Interface | Métodos | Mapeamento para ORM |
|---|---|---|
| `IJanusConnection` | `IsConnected` | Encapsula `IDBConnection` + `TFDConnection` |
| `IJanusObjectSet` | Open, OpenWhere, FindByID, RecordCount, GetRecord, NewRecord, Insert, Update, Delete | Subconjunto do `IContainerObjectSet<T>` |
| `IJanusRecord` | GetStr/SetStr, GetInt/SetInt, GetFloat/SetFloat, GetBool/SetBool | Acesso a campos sem RTTI |
| `IJanusQuery` | Where, OrderBy, PageSize, Execute | Query builder simplificado |
| `IJanusEntityBuilder` | EntityName, TableName, AddColumn, PrimaryKey, AddForeignKey, AddJoinColumn, AddAssociation, Build | Registro de entidade sem RTTI |

---

## 3. Matriz de cobertura: DLL vs 4 Modos

### Legenda
- ✅ Atendido
- ⚠️ Parcialmente atendido
- ❌ Não atendido
- 🚫 Impossível via DLL (restrição técnica)

### Funcionalidades do Modo ObjectSet (1B e 2B)

| Funcionalidade | Modo 1B (Container) | Modo 2B (Manager) | DLL Strategy 1 | DLL Strategy 2 |
|---|---|---|---|---|
| Conexão multi-banco | ✅ | ✅ | ✅ 6 bancos | ✅ 6 bancos |
| Find (todos) | ✅ | ✅ | ✅ Open | ✅ Open |
| FindWhere | ✅ | ✅ | ✅ OpenWhere | ✅ OpenWhere |
| FindByID | ✅ | ✅ | ✅ | ❌ |
| Insert | ✅ | ✅ | ✅ | ✅ |
| Update | ✅ | ✅ | ✅ | ✅ |
| Delete | ✅ | ✅ | ✅ | ✅ |
| Paginação (PageSize) | ✅ NextPacket | ✅ NextPacket | ⚠️ via Criteria | ⚠️ limitado |
| Cascade (delete/insert) | ✅ automático | ✅ automático | ✅ interno via RTTI | ⚠️ SQL manual |
| Lazy loading | ✅ LoadLazy | ✅ LoadLazy | ❌ | ❌ |
| Object state / ModifiedFields | ✅ | ✅ | ❌ | ❌ |
| Middleware (Before/After) | ✅ | ✅ | ❌ não exposto | ❌ |
| Navegação (First/Next/Eof) | ❌ | ✅ | ❌ | ❌ |
| OwnerNestedList | ❌ | ✅ | ❌ | ❌ |
| Monitor de comandos | ✅ | ✅ | ❌ | ❌ |
| Query API | separado | separado | ✅ IJanusQuery | ❌ |

### Funcionalidades do Modo DataSet (1A e 2A)

| Funcionalidade | Modo 1A (Container) | Modo 2A (Manager) | DLL |
|---|---|---|---|
| TDataSet visual (grid binding) | ✅ | ✅ | 🚫 |
| TDataSource integration | ✅ | ✅ | 🚫 |
| Master/Detail (TDataSet hierarquia) | ✅ | ✅ | 🚫 |
| AddLookupField | ✅ | ✅ | 🚫 |
| Post/Edit/Cancel (row-level) | ✅ | ✅ | 🚫 |
| DataSet events (Before/AfterScroll) | ✅ | ✅ | 🚫 |
| ApplyUpdates | ✅ | ✅ | 🚫 |

---

## 4. Análise arquitetural: por que DataSet é 🚫 na DLL

### Restrição fundamental: TDataSet não cruza fronteira DLL COM

O `TDataSet` do Delphi (e suas subclasses `TFDMemTable`, `TClientDataSet`) é um **componente visual** com:

1. **Sistema de eventos** (TNotifyEvent, OnBeforeScroll, OnAfterOpen, etc.) — delegates que dependem do memory manager do processo
2. **Máquina de estados** (dsInsert, dsEdit, dsBrowse) — estados internos não serializáveis via COM
3. **Bookmarks e Fields** (`TFields`, `TField`, `TBookmark`) — objetos Delphi managed que dependem de RTTI do processo host
4. **TDataSource binding** — ligação direta a controles visuais do mesmo processo

Esses mecanismos **não podem** ser marshalled via interfaces `stdcall` para um processo Lazarus/FPC/Delphi 7. O TDataSet precisa existir no mesmo espaço de memória que os controles visuais que o consomem.

### Alternativa teórica: Dataset virtual na DLL

Seria possível criar uma "ponte DataSet" onde a DLL gerencia um TFDMemTable interno e expõe os dados como um stream ou recordset serializado? Sim, mas:

- O consumer precisaria de um TDataSet local **próprio** (TBufDataSet no Lazarus, ou TClientDataSet no Delphi 7)
- A DLL enviaria dados serializados (JSON, binary) e o consumer popularia seu DataSet local
- Perderia: eventos do ORM, master/detail automático, cascade visual, ApplyUpdates integrado
- Essencialmente seria um "ObjectSet que serializa para DataSet local" — mesma semântica do que já existe

**Conclusão:** o modo DataSet exige que o ORM e o DataSet visual vivam no mesmo processo. A DLL atende apenas ObjectSet.

---

## 5. O que a DLL atende versus o que não atende

### ✅ A DLL atende o Modo ObjectSet (Strategy 1 — RTTI completo)

Quando o modelo é pré-compilado na DLL, o fluxo interno é equivalente ao **Modo 1B** (Container Direto + ObjectSet):

```
Consumer chama CreateObjectSet('TClientModel', conn)
  → DLL cria TEntityProxy<TClientModel>
    → internamente cria TContainerObjectSet<TClientModel>
      → usa TObjectSetAdapter<TClientModel>
        → usa TSessionObjectSet<TClientModel>
          → RTTI, DML generators, cascade, auto-increment
```

O consumer enxerga via `IJanusObjectSet` → `IJanusRecord`, mas **dentro da DLL** o engine ORM completo está rodando com RTTI, cascade, transações automáticas.

**Equivalência funcional:**

| ORM nativo (Modo 1B) | DLL (Strategy 1) | Status |
|---|---|---|
| `oMaster.Find` | `ObjectSet.Open` | ✅ equivalente |
| `oMaster.FindWhere(...)` | `ObjectSet.OpenWhere(...)` | ✅ equivalente |
| `oMaster.Find(AID)` | `ObjectSet.FindByID(AID)` | ✅ equivalente |
| `oMaster.Insert(obj)` | `ObjectSet.Insert(rec)` | ✅ equivalente |
| `oMaster.Update(obj)` | `ObjectSet.Update(rec)` | ✅ equivalente |
| `oMaster.Delete(obj)` | `ObjectSet.Delete(rec)` | ✅ equivalente |
| `oMaster.NextPacket` | `Criteria.PageSize(N).Execute` | ⚠️ parcial |

### ⚠️ A DLL exporta `NewManagerObjectSet` mas é inutilizável

O `JanusFramework.dpr` exporta `NewManagerObjectSet` que retorna `TManagerObjectSet.Create(nil)`:

```delphi
function NewManagerObjectSet: TManagerObjectSet; stdcall; export;
begin
  Result := TManagerObjectSet.Create(nil);
end;
```

**Problema:** `TManagerObjectSet` usa generics em toda sua API pública:
- `AddAdapter<T>` — genérico
- `Find<T>` — genérico
- `Current<T>` — genérico
- `Insert<T>` — genérico

Um consumer Lazarus/FPC **não pode chamar métodos genérics** de um objeto Delphi recebido via DLL. O tipo `T` só existe no contexto de compilação do Delphi.

**Veredicto:** `NewManagerObjectSet` é um export residual sem utilidade prática. O Modo 2B (Manager) não funciona diretamente pela DLL.

### ❌ Funcionalidades do Manager que a DLL não cobre

| Funcionalidade Manager | Viabilidade na DLL | Complexidade |
|---|---|---|
| `OwnerNestedList` (navegação stateful) | Possível via nova interface | Média |
| `First<T>` / `Next<T>` / `Eof<T>` | Possível via IJanusObjectSet estendido | Baixa |
| `Current<T>` | Possível via IJanusRecord com index | Baixa |
| `ModifiedFields` | Possível via nova interface | Média |
| `AddAdapter<T>` (multi-entity) | Possível via IJanusManager.AddEntity(name) | Alta |
| Master/Detail em memória | Possível via associações programáticas | Alta |
| Middleware callbacks | Difícil — callbacks cruzam fronteira DLL | Muito alta |

---

## 6. Resumo executivo

### O que a DLL atende hoje

| Modo ORM | Atendido? | Via |
|---|---|---|
| **1A — Container + DataSet** | 🚫 Impossível | TDataSet não cruza DLL |
| **1B — Container + ObjectSet** | ✅ Atendido | Strategy 1 (RTTI interna) usa `TContainerObjectSet<T>` por baixo |
| **2A — Manager + DataSet** | 🚫 Impossível | TDataSet não cruza DLL |
| **2B — Manager + ObjectSet** | ❌ Não atendido | Generics do Manager não cruzam DLL |

### Lacunas priorizadas (se quiser evoluir a DLL)

| Prioridade | Gap | Esforço | Benefício |
|---|---|---|---|
| 1 | Navegação stateful (First/Next/Eof) no ObjectSet | Baixo | Emula o Manager no consumer |
| 2 | NextPacket incremental | Baixo | Paginação real sem recarregar tudo |
| 3 | `IJanusManager` non-generic facade | Alto | Multi-entity orquestrado via DLL |
| 4 | ModifiedFields / change tracking | Médio | Detecção de mudanças |
| 5 | Master/Detail em memória | Alto | Hierarquias via DLL |
| 6 | Stream-based DataSet bridge | Muito alto | DataSet local populado pela DLL |

### Recomendação arquitetural

A DLL **já atende** a forma mais importante para consumers Lazarus/FPC: **CRUD completo via ObjectSet (Strategy 1)** com o engine ORM real rodando internamente. O consumer não precisa saber que existe TContainerObjectSet/TObjectSetAdapter por baixo — ele usa IJanusObjectSet/IJanusRecord.

Para alcançar paridade com o **Modo 2B** (Manager + ObjectSet), a evolução mais natural seria criar um `IJanusManager` non-generic na DLL que:
- Aceita nomes de entidades como strings (não generics)
- Mantém estado de navegação internamente
- Expõe First/Next/Current/Eof via interface COM-safe
- Delega para `TManagerObjectSet` internamente

O modo DataSet (1A e 2A) **não é viável** via DLL — mas o paradigma ObjectSet da DLL pode alimentar um DataSet local no Lazarus (TBufDataSet) se o consumer quiser binding visual.
