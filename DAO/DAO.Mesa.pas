unit DAO.Mesa;

interface

uses Firedac.Comp.Client,
     FireDAC.DApt,
     System.JSON,
     DataSet.Serialize,
     DAO.Connection,
     System.SysUtils;


type
  TDAOMesa = class(TDAOConnection)
  private

  public
    function  Listar(): TJSONArray;
    function  Transferencia(id_mesa_origem, id_mesa_destino: integer): TJSONObject;
    function  Reserva(id_mesa: integer; nome_reserva: string): TJSONObject;
    function  ListarId(id_mesa: integer): TJSONObject;
    procedure CancelarReserva(id_mesa: integer);
  end;

implementation

uses
  Core.Utils.Tipos;

function TDAOMesa.Listar(): TJSONArray;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select m.id_mesa, m.numero_mesa, m.status, s.descricao as descr_status, s.cor, ');
    qry.SQL.Add('m.nome_reserva, coalesce(sum(p.vl_total), 0) as vl_total');
    qry.SQL.Add('from mesa m                                             ');
    qry.SQL.Add('join mesa_status s on (s.status = m.status)             ');
    qry.SQL.Add('left join comanda c on (c.id_mesa = m.id_mesa and c.status = ''A'')');
    qry.SQL.Add('left join pedido p on (p.id_comanda = c.id_comanda)');
    qry.SQL.Add('group by m.id_mesa, m.numero_mesa, m.status, m.nome_reserva, s.descricao, s.cor');
    qry.SQL.Add('order by m.numero_mesa                                                         ');
    qry.Active := true;

    Result := qry.ToJSONArray;

  finally
    qry.Free;
  end;
end;

function TDAOMesa.ListarId(id_mesa: integer): TJSONObject;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select * from mesa      ');
    qry.SQL.Add('where id_mesa = :id_mesa');
    qry.ParamByName('id_mesa').Value := id_mesa;
    qry.Active := true;

    Result := qry.ToJSONObject;


    // Tratamento das comandas...
    qry.Active := false;
    qry.SQL.Clear;
    qry.SQL.Add('select                                                                                          ');
    qry.SQL.Add(' c.id_comanda,                                                                                  ');
    qry.SQL.Add(' c.cliente_comanda,                                                                             ');
    qry.SQL.Add(' c.status,                                                                                      ');
    qry.SQL.Add(' c.dt_abertura, c.dt_fechamento,                                                                ');
    qry.SQL.Add('c.id_usuario, COALESCE(sum(p.vl_total), 0) as vl_total                                          ');
    qry.SQL.Add('from comanda c                                                                                  ');
    qry.SQL.Add('left join pedido p on (p.id_comanda = c.id_comanda)                                              '); //and p.status = :status_pedido)');
    qry.SQL.Add('where c.id_mesa = :id_mesa and c.status = :status                          ');
    qry.SQL.Add('group by c.id_comanda, c.cliente_comanda, c.status, c.dt_abertura, c.dt_fechamento, c.id_usuario');
    qry.SQL.Add('order by c.cliente_comanda');

    qry.ParamByName('id_mesa').Value       := id_mesa;
    qry.ParamByName('status').Value        := StatusComanda[Integer(TStatusComanda.tscAberta)];
//    qry.ParamByName('status_pedido').Value := StatusPedido[Integer(TStatusPedido.tspAberto)];
    qry.Active := true;

    Result.AddPair('comandas', qry.ToJSONArray);

  finally
    qry.Free;
  end;
end;

function TDAOMesa.Reserva(id_mesa: integer; nome_reserva: string): TJSONObject;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;
    qry.SQL.Add('update mesa set status = :status, nome_reserva = :nome_reserva');
    qry.SQL.Add('where id_mesa = :id_mesa');
    qry.SQL.Add('returning id_mesa');

    qry.ParamByName('status').Value       := StatusMesa[Integer(TStatusMesa.tsmReservada)];
    qry.ParamByName('nome_reserva').Value := nome_reserva;
    qry.ParamByName('id_mesa').Value      := id_mesa;

    qry.Active := true;

    Result := qry.ToJSONObject;

  finally
    qry.Free;
  end;
end;

function TDAOMesa.Transferencia(id_mesa_origem,
                                id_mesa_destino: integer): TJSONObject;
var
  qry: TFDQuery;
begin
  try
    try
      Self.StartTransaction;

      qry := TFDQuery.Create(nil);
      qry.Connection := Self.Connection;
      qry.SQL.Add('update comanda set id_mesa = :id_mesa_destino');
      qry.SQL.Add('where id_mesa = :id_mesa_origem');
      qry.SQL.Add('and status = :status');
      qry.ParamByName('id_mesa_destino').Value := id_mesa_destino;
      qry.ParamByName('id_mesa_origem').Value  := id_mesa_origem;
      qry.ParamByName('status').Value          := StatusComanda[Integer(TStatusComanda.tscAberta)];
      qry.ExecSQL;

      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('update mesa set status = :status where id_mesa = :id_mesa');
      qry.ParamByName('status').Value  := StatusMesa[Integer(TStatusMesa.tsmLivre)];
      qry.ParamByName('id_mesa').Value := id_mesa_origem;
      qry.ExecSQL;

      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('update mesa set status = :status where id_mesa = :id_mesa');
      qry.ParamByName('status').Value := StatusMesa[Integer(TStatusMesa.tsmOcupada)];
      qry.ParamByName('id_mesa').Value := id_mesa_destino;
      qry.ExecSQL;

      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('select id_mesa from mesa where id_mesa = :id_mesa');
      qry.ParamByName('id_mesa').Value := id_mesa_destino;
      qry.Active := true;

      Result := qry.ToJSONObject;

      Self.Commit;

    except on ex:exception do
      begin
        Self.Rollback;
        raise Exception.Create(ex.message);
      end;
    end;

  finally
    qry.Free;
  end;
end;

procedure TDAOMesa.CancelarReserva(id_mesa: integer);
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;
    qry.SQL.Add('update mesa set status = :status, nome_reserva = null');
    qry.SQL.Add('where id_mesa = :id_mesa');

    qry.ParamByName('status').Value := StatusMesa[Integer(TStatusMesa.tsmLivre)];
    qry.ParamByName('id_mesa').Value := id_mesa;

    qry.ExecSQL;

  finally
    qry.Free;
  end;
end;

end.
