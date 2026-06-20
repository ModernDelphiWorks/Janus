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
  @abstract(REST Componentes)
  @created(20 Jun 2018)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit Janus.Server.Resource.WiRL;

{$IFDEF JANUS_REST_WIRL}

interface

uses
  SysUtils,
  // WiRL
  WiRL.Core.Registry,
  WiRL.Core.Attributes,
  WiRL.http.Accept.MediaType,
  // Janus
  Janus.Server.RestQuery.Parse,
  Janus.Server.Resource;

type
  [Path('/Janus')]
  TAppResource = class(TAppResourceBase)
  public
    constructor Create; overload; virtual;
    destructor Destroy; override;

    [GET, Path('/{resource}?')]
    [Produces(TMediaType.TEXT_PLAIN)]
    [Produces(TMediaType.APPLICATION_JSON)]
    function select([PathParam] resource: string;
                    [QueryParam('$filter')] filter: string;
                    [QueryParam('$orderby')] orderby: string;
                    [QueryParam('$top')] top: string;
                    [QueryParam('$skip')] skip: string;
                    [QueryParam('$count')] count: string): string; overload;

    [POST, Path('/{resource}')]
    [Produces(TMediaType.TEXT_PLAIN)]
    [Produces(TMediaType.APPLICATION_JSON)]
    function insert([PathParam] resource: string;
                    [BodyParam] value: string): string; overload;

    [PUT, Path('/{resource}')]
    [Produces(TMediaType.TEXT_PLAIN)]
    [Produces(TMediaType.APPLICATION_JSON)]
    function update([PathParam] resource: string;
                    [BodyParam] value: string): string; overload;

    [DELETE, Path('/{resource}?')]
    [Produces(TMediaType.TEXT_PLAIN)]
    [Produces(TMediaType.APPLICATION_JSON)]
    function delete([PathParam] resource: string;
                    [QueryParam('$filter')] filter: string): string; overload;
  end;

implementation

uses
  Janus.Server.WiRL;

{ TAppResource }

constructor TAppResource.Create;
begin
  Create(TRESTServerWiRL.GetConnection);
end;

destructor TAppResource.Destroy;
begin

  inherited;
end;

function TAppResource.select(resource: string;
                             filter: string;
                             orderby: string;
                             top: string;
                             skip: string;
                             count: string): string;
var
  LQuery: TRESTQueryParse;
begin
  LQuery := TRESTQueryParse.Create;
  try
    // Parse da Query passada na URI
    LQuery.ParseQuery(resource);
    if LQuery.ResourceName <> '' then
    begin
      LQuery.SetFilter(filter);
      LQuery.SetOrderBy(orderby);
      LQuery.SetTop(top);
      LQuery.SetSkip(skip);
      LQuery.SetCount(count);
      // Retorno JSON
      Result := ParseFind(LQuery);
    end
    else
      raise Exception.Create('Class ' + LQuery.ResourceName + 'not found!');
  finally
    LQuery.Free;
  end;
end;

function TAppResource.insert(resource: string; value: string): string;
begin
  Result := inherited;
end;

function TAppResource.update(resource: string; value: string): string;
begin
  Result := inherited;
end;

function TAppResource.delete(resource: string;
                             filter: string): string;
var
  LQuery: TRESTQuery;
begin
  LQuery := TRESTQuery.Create;
  try
    // Parse da Query passada na URI
    LQuery.ParseQuery(resource);
    if LQuery.ResourceName <> '' then
    begin
      LQuery.SetFilter(filter);
      // Retorno JSON
      Result := ParseDelete(LQuery);
    end
    else
      raise Exception.Create('Class ' + LQuery.ResourceName + 'not found!');
  finally
    LQuery.Free;
  end;
end;

initialization
  TWiRLResourceRegistry.Instance.RegisterResource<TAppResource>;

{$ELSE}
interface
implementation
{$ENDIF}

end.
