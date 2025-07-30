unit DAO.LocalPreparo;

interface

uses Firedac.Comp.Client,
     FireDAC.DApt,
     System.JSON,
     DataSet.Serialize,
     DAO.Connection,
     System.SysUtils;


type
  TDAOLocalPreparo = class(TDAOConnection)
  private
  public
    function Listar(): TJSONArray;
  end;

implementation

function TDAOLocalPreparo.Listar(): TJSONArray;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select * from local_preparo order by nome');
    qry.Active := true;

    Result := qry.ToJSONArray;

  finally
    qry.Free;
  end;
end;


end.
