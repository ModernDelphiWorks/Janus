unit Janus.Server.Swagger.Horse;

interface

uses
  SysUtils,
  GBSwagger.Model.Interfaces,
  GBSwagger.Model.Attributes,
  Janus.Server.Resource.Horse,
  Janus.Model.Master;

type
  TJanusSwagger = class
  strict private
    class var FResource: String;
  public
    class constructor Create;
    class property Resource: String read FResource write FResource;
  end;

implementation

{ TJanusSwagger }

class constructor TJanusSwagger.Create;
begin
  FResource := 'Resourcename';
end;

initialization

  Swagger
//    .Register
//      .SchemaOnError(Exception)
//    .&End
    .BasePath('Janus/swagger/doc')
    .Info
      .Title('Janus Server')
      .Description('API RESTful')
      .Contact
        .Name('Contact Isaque Pinheiro')
        .Email('isaquesp@gmail.com.br')
        .URL('https://www.isaquepinheiro.com.br')
      .&End
    .&End
    .BasePath('v1');

    Swagger.Path(Format('api/Janus/:%s', [TJanusSwagger.Resource]))
      .Tag(Format('%s', [TJanusSwagger.Resource]))
      .GET.Summary('Select')
      .AddResponse(400).&End
      .AddResponse(200, 'Json data').Schema(Tmaster).&End;

    Swagger.Path(Format('api/Janus/:%s(id)', [TJanusSwagger.Resource]))
      .Tag(Format('%s', [TJanusSwagger.Resource]))
      .GET.Summary('Select')
      .AddParamPath('id', Format('%s ID', [TJanusSwagger.Resource])).&End
      .AddResponse(400).&End
      .AddResponse(200, 'Json data').Schema(Tmaster).&End;

    Swagger.Path(Format('api/Janus/:%s?$', [TJanusSwagger.Resource]))
      .Tag(Format('%s', [TJanusSwagger.Resource]))
      .GET.Summary('Select')
      .AddParamQuery('query', 'OData (Open Data Protocol)').&End
      .Description('https://www.odata.org/getting-started/basic-tutorial/')
      .AddResponse(400).&End
      .AddResponse(200, 'Json data').Schema(Tmaster).&End;

// Exemples (OData):
// http://localhost:9000/api/Janus/master
// http://localhost:9000/api/Janus/master(7)
// http://localhost:9000/api/Janus/master?$filter=master_id eq 7
// http://localhost:9000/api/Janus/master?$filter=master_id gt 1 and master_id lt 10&$orderby=description desc
// http://localhost:9000/api/Janus/master?$skip=2&$top=1

finalization

end.
