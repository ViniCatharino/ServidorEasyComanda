unit Controllers.Mesa;

interface

uses Horse,
     Horse.JWT,
     System.JSON,
     System.SysUtils,
     DAO.Mesa,
     uMD5,
     Controllers.Auth;

procedure RegistrarRotas;
procedure Listar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure ListarId(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure Transferencia(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure Reserva(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure CancelarReserva(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

procedure RegistrarRotas;
begin
  THorse{.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims))) }
        .get('/mesas', Listar);

  THorse//.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))
        .get('/mesas/:id_mesa', ListarId);

  THorse.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))
        .post('/mesas/:id_mesa/transferencia', Transferencia);

  THorse.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))
        .post('/mesas/:id_mesa/reserva', Reserva);

  THorse.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))
        .delete('/mesas/:id_mesa/reserva', CancelarReserva);
end;

procedure Listar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOMesa: TDAOMesa;
begin
  DAOMesa := nil;

  try
    try
      DAOMesa := TDAOMesa.Create;

      Res.Send<TJSONArray>(DAOMesa.Listar());

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOMesa.Free;
  end;
end;

procedure Transferencia(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOMesa: TDAOMesa;
  body: TJSONObject;
  id_mesa_origem, id_mesa_destino: integer;
begin
  DAOMesa := nil;

  try
    try
      DAOMesa := TDAOMesa.Create;

      id_mesa_origem := req.Params['id_mesa'].ToInteger;

      body := req.Body<TJSONObject>;
      id_mesa_destino := body.GetValue<integer>('id_mesa_destino', 0);

      Res.Send<TJSONObject>(DAOMesa.Transferencia(id_mesa_origem, id_mesa_destino));

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOMesa.Free;
  end;
end;

procedure Reserva(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOMesa: TDAOMesa;
  body: TJSONObject;
  id_mesa: integer;
  nome_reserva: string;
begin
  DAOMesa := nil;

  try
    try
      DAOMesa := TDAOMesa.Create;

      id_mesa := req.Params['id_mesa'].ToInteger;

      body         := req.Body<TJSONObject>;
      nome_reserva := UpperCase(body.GetValue<string>('nome_reserva', ''));

      Res.Send<TJSONObject>(DAOMesa.Reserva(id_mesa, nome_reserva));

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOMesa.Free;
  end;
end;

procedure CancelarReserva(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOMesa: TDAOMesa;
  id_mesa: integer;
begin
  DAOMesa := nil;

  try
    try
      DAOMesa := TDAOMesa.Create;

      id_mesa := req.Params['id_mesa'].ToInteger;

      DAOMesa.CancelarReserva(id_mesa);

      Res.Send('OK');

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOMesa.Free;
  end;
end;

procedure ListarId(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOMesa: TDAOMesa;
  id_mesa: integer;
begin
  DAOMesa := nil;

  try
    try
      DAOMesa := TDAOMesa.Create;

      id_mesa := req.Params['id_mesa'].ToInteger;

      Res.Send<TJSONObject>(DAOMesa.ListarId(id_mesa));

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOMesa.Free;
  end;
end;

end.
