unit Janus.CodeGen.Template;

interface

uses
  SysUtils,
  Classes,
  Generics.Collections;

type
  TJanusCodeTemplate = class
  public
    class function Apply(const ATemplate: String;
      const APlaceholders: TDictionary<String, String>): String;
  end;

const
  sUnitTemplate =
    'unit {{UnitName}};' + sLineBreak +
    '' + sLineBreak +
    'interface' + sLineBreak +
    '' + sLineBreak +
    'uses' + sLineBreak +
    '  DB, ' + sLineBreak +
    '  Classes, ' + sLineBreak +
    '  SysUtils, ' + sLineBreak +
    '  Generics.Collections, ' + sLineBreak +
    '' + sLineBreak +
    '  /// orm ' + sLineBreak +
    '{{UsesRelations}}' +
    '  Janus.Types.Blob, ' + sLineBreak +
    '  Janus.Types.Lazy, ' + sLineBreak +
    '  MetaDbDiff.types.mapping, ' + sLineBreak +
    '  Janus.Types.Nullable, ' + sLineBreak +
    '  MetaDbDiff.mapping.classes, ' + sLineBreak +
    '  MetaDbDiff.mapping.register, ' + sLineBreak +
    '  MetaDbDiff.mapping.attributes; ' + sLineBreak +
    '' + sLineBreak +
    'type' + sLineBreak +
    '  [Entity]' + sLineBreak +
    '  [Table({{TableNameQuoted}}, '''')]' + sLineBreak +
    '{{PrimaryKeyAttributes}}' +
    '{{IndexAttributes}}' +
    '{{CheckAttributes}}' +
    '  T{{ClassName}} = class' + sLineBreak +
    '  private' + sLineBreak +
    '    { Private declarations } ' + sLineBreak +
    '{{PrivateFields}}' +
    '{{RelationFields}}' +
    '  public ' + sLineBreak +
    '    { Public declarations } ' + sLineBreak +
    '{{ConstructorDeclaration}}' +
    '{{DestructorDeclaration}}' +
    '{{Properties}}' +
    '{{RelationProperties}}' +
    '  end;' + sLineBreak +
    '' + sLineBreak +
    'implementation' + sLineBreak +
    '{{ConstructorImplementation}}' +
    '{{DestructorImplementation}}' +
    '{{LazyLoadImplementation}}' +
    '' + sLineBreak +
    'initialization' + sLineBreak +
    '  TRegisterClass.RegisterEntity(T{{ClassName}})' + sLineBreak +
    '' + sLineBreak +
    'end.';

  sColumnAttributeTemplate =
    '    [Column({{ColumnParams}})]';

  sPrimaryKeyAttributeTemplate =
    '  [PrimaryKey({{PKParams}})]';

  sForeignKeyAttributeTemplate =
    '    [ForeignKey({{FKParams}})]';

  sAssociationAttributeTemplate =
    '    [Association({{AssocParams}})]';

  sDictionaryAttributeTemplate =
    '    [Dictionary({{DictParams}})]';

  sRestrictionAttributeTemplate =
    '    [Restrictions([NotNull])]';

  sPropertyTemplate =
    '    property {{PropertyName}}: {{PropertyType}}{{ReadWrite}};';

  sFieldTemplate =
    '    F{{FieldName}}: {{FieldType}};';

implementation

{ TJanusCodeTemplate }

class function TJanusCodeTemplate.Apply(const ATemplate: String;
  const APlaceholders: TDictionary<String, String>): String;
var
  LKey: String;
  LValue: String;
begin
  Result := ATemplate;
  for LKey in APlaceholders.Keys do
  begin
    APlaceholders.TryGetValue(LKey, LValue);
    Result := StringReplace(Result, '{{' + LKey + '}}', LValue, [rfReplaceAll]);
  end;
end;

end.
