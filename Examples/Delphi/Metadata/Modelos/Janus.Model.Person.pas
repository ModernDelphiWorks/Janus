unit Janus.Model.Person;

interface

uses
  Classes,
  DB,
  /// orm
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('Person','Tabela de pessoas')]
  [PrimaryKey('Id', AutoInc, NoSort, False, 'Chave prim�ria')]
  [Indexe('IDX_FirstName','FirstName', NoSort, True, 'Indexe por nome')]
  [Check('CHK_Age', 'Age >= 0')]
  [Sequence('SEQ_PERSON')]
  TPerson = class
  private
    { Private declarations }
    FId: Integer;
    FFirstName: String;
    FLastName: String;
    FAge: Integer;
    FSalary: Double;
  public
    { Public declarations }
    [Restrictions([NoUpdate, NotNull])]
    [Column('Id', ftInteger)]
    [Dictionary('C�digo ID','Mensagem de valida��o','0','','',taCenter)]
    property Id: Integer Index 0 read FId write FId;

    [Restrictions([NotNull])]
    [Column('FirstName', ftString, 40)]
    [Dictionary('Primeiro nome','Mensagem de valida��o','','','',taLeftJustify)]
    property FirstName: String Index 1 read FFirstName write FFirstName;

    [Restrictions([NotNull])]
    [Column('LastName', ftString, 60)]
    [Dictionary('�ltimo nome','Mensagem de valida��o','','','',taLeftJustify)]
    property LastName: String Index 2 read FLastName write FLastName;

    [Restrictions([NotNull])]
    [Column('Age', ftInteger)]
    [Dictionary('Idade','Mensagem de valida��o','0','','',taCenter)]
    property Age: Integer Index 3 read FAge write FAge;

    [Restrictions([NotNull])]
    [Column('Salary', ftBCD, 18, 3)]
    [Dictionary('Pre�o','Mensagem de valida��o','0','','',taRightJustify)]
    property Salary: Double Index 4 read FSalary write FSalary;

  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TPerson);

end.

