unit Controllers.LocalPreparo;

interface

uses Horse,
     Horse.JWT,
     System.JSON,
     System.SysUtils,
     DAO.LocalPreparo,
     Controllers.Auth;

procedure RegistrarRotas;
procedure Listar(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

procedure RegistrarRotas;
begin
  THorse.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))
        .get('/locais', Listar);
end;

procedure Listar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOLocal: TDAOLocalPreparo;
begin
  DAOLocal := nil;

  try
    try
      DAOLocal := TDAOLocalPreparo.Create;

      Res.Send<TJSONArray>(DAOLocal.Listar());

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOLocal.Free;
  end;
end;



end.
