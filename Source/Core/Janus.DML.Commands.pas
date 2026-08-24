{
  ------------------------------------------------------------------------------
  Janus ORM
  State-of-the-art Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2025-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

unit Janus.DML.Commands;

interface

uses
  Rtti,
  SysUtils,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes;

type
  TDMLCommandAutoInc = class
  private
    FSequence: TSequenceMapping;
    FPrimaryKey: TPrimaryKeyMapping;
    FExistSequence: Boolean;
  public
    property Sequence: TSequenceMapping read FSequence write FSequence;
    property PrimaryKey: TPrimaryKeyMapping read FPrimaryKey write FPrimaryKey;
    property ExistSequence: Boolean read FExistSequence write FExistSequence;
  end;

  /// <summary> THE ONE AXIS OF GUID STORAGE THAT GENUINELY DIVERGES, AND THE
  ///  ONLY PLACE THIS HOUSE ANSWERS ABOUT IT. Issues #284, #290, #294.
  ///
  ///  IOptions.StoreGUIDAsOctet is not a future hypothesis: it is a public
  ///  setter, live today (DataEngine.DriverConnection.pas:123, default False in
  ///  :1904). With it on, the DDL of this ecosystem stops storing TEXT and
  ///  starts storing 16 RAW BYTES - MetaDbDiff.Metadata.Extract.pas:509-526
  ///  emits CHAR(16) CHARACTER SET OCTETS on Firebird and BYTE(16) on
  ///  PostgreSQL. Every path in Janus that renders a ftGuid column renders the
  ///  38-character text of TGUID.ToString instead, whether it goes into the
  ///  statement as a literal (the association SELECT) or down as a bound
  ///  parameter (the three write commands). Against a 16-byte column that text
  ///  matches ZERO ROWS IN SILENCE on a lookup, and stores what no lookup will
  ///  find on a write - which is issue #284's defect coming back through
  ///  another door.
  ///
  ///  THE REFUSAL IS THE ANSWER, AND HERE IS THE CONDITION FOR LIFTING IT.
  ///  Octet mode HAS NO WORKING END-TO-END PATH IN ANY DIALECT of this house -
  ///  not one, and the refusal is deliberate rather than an oversight. The
  ///  correct form is per dialect and cannot be chosen from a reading: on
  ///  Firebird a CHAR(16) CHARACTER SET OCTETS column is reached either through
  ///  CHAR_TO_UUID('36 with hyphens') or through an x'32hex' literal, and which
  ///  one - and in which byte order - is a property of the running server; on
  ///  PostgreSQL the octet DDL itself is in dispute, because BYTE(16) is not a
  ///  PostgreSQL type at all (its binary type is bytea). WHAT WOULD LIFT THIS
  ///  GUARD IS MEASUREMENT AGAINST A LIVE DATABASE - Firebird under CHARACTER
  ///  SET OCTETS and PostgreSQL over bytea, written and read back - and nothing
  ///  short of that. Choosing a spelling without measuring one would be
  ///  inventing, and the named error at least turns a silence into a
  ///  conversation. It costs nothing to anyone on the default.
  ///
  ///  ONE IMPLEMENTATION, DELIBERATELY, AND IT LIVES HERE RATHER THAN ON THE
  ///  GENERATOR. It began as a private method of TDMLGeneratorAbstract, which
  ///  the write commands cannot reach: they hold the generator only as
  ///  IDMLGeneratorCommand, and widening a published interface breaks any
  ///  third-party implementer - the objection recorded over
  ///  TDMLGeneratorAbstract.GetGeneratorWhere. This unit is a leaf that both
  ///  sides already name, so the refusal has one spelling and one place to
  ///  change. AOperation is the only thing that varies: it names the path the
  ///  caller was on, so the message says what refused as well as why. </summary>
  TGuidOctetRefusal = record
  strict private
    class function _Enabled(const AConnection: IDBConnection): Boolean; static;
  public
    class procedure Check(const AConnection: IDBConnection;
      AProperty: TRttiProperty; const AOperation: String); static;
  end;

implementation

{ TGuidOctetRefusal }

class function TGuidOctetRefusal._Enabled(const AConnection: IDBConnection): Boolean;
var
  LOptions: IOptions;
begin
  // Nil-safe on BOTH levels on purpose: a generator can be built without
  // SetConnection (the factory registration does not require it), and an
  // IDBConnection may answer nil for Options - which is what the test double
  // does. Neither case is "octet"; both are "I do not know", and not knowing
  // must not raise on a path that works today.
  Result := False;
  if AConnection = nil then
    Exit;
  LOptions := AConnection.Options;
  if LOptions = nil then
    Exit;
  Result := LOptions.StoreGUIDAsOctet;
end;

class procedure TGuidOctetRefusal.Check(const AConnection: IDBConnection;
  AProperty: TRttiProperty; const AOperation: String);
begin
  if not _Enabled(AConnection) then
    Exit;
  raise Exception.CreateFmt(
    'A conexao esta com IOptions.StoreGUIDAsOctet ligada, e a coluna ftGuid ' +
    'mapeada na propriedade "%s" entra %s. Nesse modo o schema guarda o GUID ' +
    'como BINARIO de 16 bytes (Firebird: CHAR(16) CHARACTER SET OCTETS; ' +
    'PostgreSQL: BYTE(16)), e a forma de TEXTO de 38 caracteres que este ' +
    'caminho produz nao corresponde a essa coluna: num WHERE ela casa ZERO ' +
    'LINHAS em silencio, e numa gravacao ela guarda o que nenhuma leitura vai ' +
    'achar. O modo octeto ainda NAO tem caminho fim-a-fim em dialeto nenhum - ' +
    'ou desligue StoreGUIDAsOctet para esta conexao, ou implemente a forma ' +
    'octeto do dialeto, meca-a contra banco vivo, e remova esta guarda.',
    [AProperty.Name, AOperation]);
end;

end.
