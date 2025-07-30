unit DAO.Comanda;

interface

uses Firedac.Comp.Client,
     FireDAC.DApt,
     DataSet.Serialize,
     DAO.Connection,
     System.SysUtils,
     System.JSON;


type
  TDAOComanda = class(TDAOConnection)
  private
    FCodigoResposta: integer;
    function VerificaItensParaEntrega(AIdComanda : integer): Boolean;
  public
    function ListarConsumo(id_comanda: integer): TJSONArray;
    function Encerrar(id_comanda: integer): TJSONObject;
    function AbrirComanda(id_usuario, id_mesa: integer;
                          cliente_comanda: string): TJsonObject;
    function CodigoResposta: integer;
  end;

implementation

uses
  Horse, Core.Utils.Tipos;


function TDAOComanda.ListarConsumo(id_comanda: integer): TJSONArray;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('SELECT                                                          ');
    qry.SQL.Add('    i.*,                                                        ');
    qry.SQL.Add('    o.descricao,                                                ');
    qry.SQL.Add('    o.preco,                                                    ');
    qry.SQL.Add('    COALESCE(adi.total_adicionais, 0) AS total_adicionais,      ');
    qry.SQL.Add('    o.preco + COALESCE(adi.total_adicionais, 0) AS preco_total, ');
    qry.SQL.Add('    i.id_item AS id_item_pedido                                 ');
    qry.SQL.Add('FROM pedido p                                                   ');
    qry.SQL.Add('JOIN pedido_item i      ON i.id_pedido =  p.id_pedido            ');
    qry.SQL.Add('JOIN produto o          ON o.id_produto = i.id_produto          ');
    qry.SQL.Add('LEFT JOIN (                                                     ');
    qry.SQL.Add('    SELECT                                                      ');
    qry.SQL.Add('        id_item_pedido,                                         ');
    qry.SQL.Add('        SUM(valor) AS total_adicionais                          ');
    qry.SQL.Add('    FROM adicionais_item                                        ');
    qry.SQL.Add('    GROUP BY id_item_pedido                                     ');
    qry.SQL.Add(') adi ON adi.id_item_pedido = i.id_item                         ');
    qry.SQL.Add('WHERE p.id_comanda = :id_comanda                                ');
    qry.SQL.Add('ORDER BY i.id_item                                              ');


    qry.ParamByName('id_comanda').Value := id_comanda;
    qry.Active := true;

    Result := qry.ToJSONArray;

  finally
    qry.Free;
  end;
end;

function TDAOComanda.VerificaItensParaEntrega(AIdComanda: integer): Boolean;
var
  qry : TFDQuery;
begin
  Result := False;
  qry := TFDQuery.Create(Nil);
  qry.Connection := Self.Connection;

  try
    qry.Active := False;
    qry.SQL.Clear;
    qry.SQL.Add('SELECT COUNT(*) FROM pedido_item PI                    ');
    qry.SQL.Add('LEFT JOIN PEDIDO P ON P.id_pedido = PI.id_pedido       ');
    qry.SQL.Add('WHERE P.id_comanda = :ID_COMANDA AND PI.status = ''A'' ');
    qry.ParamByName('ID_COMANDA').Value := AIdComanda;
    qry.Open;

    if qry.FieldByName('COUNT').AsInteger > 0 then
    begin
      Result := True;
    end;
  finally
    qry.Free;
  end;
end;

function TDAOComanda.CodigoResposta: integer;
begin
  Result := FCodigoResposta;
end;

function TDAOComanda.Encerrar(id_comanda: integer): TJSONObject;
var
  qry         : TFDQuery;
  LJSONRetorno: TJSONObject;
  id_mesa, qtd_comanda: integer;
begin
  try
    FCodigoResposta := Integer(THTTPStatus.OK);
    LJSONRetorno    := TJSONObject.Create;
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    if VerificaItensParaEntrega(id_comanda) then
    begin
      LJSONRetorno.AddPair('message', 'Comanda com pedidos a serem entregue!! Verifique');
      FCodigoResposta := Integer(THTTPStatus.BadRequest);
      Result          := LJSONRetorno;
      Exit;
    end;

    try
      Self.StartTransaction;

      // Descobrir qual é a mesa da comanda...
      qry.SQL.Add('select id_mesa from comanda');
      qry.SQL.Add('where id_comanda = :id_comanda');
      qry.ParamByName('id_comanda').Value := id_comanda;
      qry.Active := true;

      id_mesa := qry.FieldByName('id_mesa').AsInteger;


      // Encerra a comanda em questao...
      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('update comanda set status = :status');
      qry.SQL.Add('where id_comanda = :id_comanda');
      qry.ParamByName('status').Value     := StatusComanda[Integer(TStatusComanda.tscEncerrada)];
      qry.ParamByName('id_comanda').Value := id_comanda;
      qry.ExecSQL;


      // Atualiza status do pedido...
      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('update pedido set status = :status');
      qry.SQL.Add('where id_comanda = :id_comanda');
      qry.ParamByName('status').Value     := StatusPedido[Integer(TStatusPedido.tspEntregue)];
      qry.ParamByName('id_comanda').Value := id_comanda;
      qry.ExecSQL;


      // Verificar quantas comandas ainda existem em aberto...
      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('select id_comanda from comanda');
      qry.SQL.Add('where id_mesa = :id_mesa and status = :status');
      qry.ParamByName('id_mesa').Value := id_mesa;
      qry.ParamByName('status').Value := StatusComanda[Integer(TStatusComanda.tscAberta)];;
      qry.Active := true;

      qtd_comanda := qry.RecordCount;


      // Verifica se deve liberar a mesa...
      if qtd_comanda = 0 then
      begin
        qry.Active := false;
        qry.SQL.Clear;
        qry.SQL.Add('update mesa set status = :status');
        qry.SQL.Add('where id_mesa = :id_mesa');
        qry.ParamByName('id_mesa').Value := id_mesa;
        qry.ParamByName('status').Value  := StatusMesa[Integer(TStatusMesa.tsmLivre)];
        qry.ExecSQL;
      end;

      Self.Commit;
      Result := LJSONRetorno;

    except on ex:exception do
      begin
        Self.Rollback;
        Result := LJSONRetorno;
        raise Exception.Create(ex.Message);
      end;
    end;

  finally
    qry.Free;
  end;
end;

function TDAOComanda.AbrirComanda(id_usuario, id_mesa: integer;
                                  cliente_comanda: string): TJsonObject;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    try
      Self.StartTransaction;

      // Atualizar status mesa...
      qry.SQL.Add('update mesa set status = :status');
      qry.SQL.Add('where id_mesa = :id_mesa');
      qry.ParamByName('id_mesa').Value := id_mesa;
      qry.ParamByName('status').Value  := StatusMesa[Integer(TStatusMesa.tsmOcupada)];
      qry.ExecSQL;


      // Cadastrar nova comanda...
      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('insert into comanda(id_mesa, cliente_comanda, status, dt_abertura, id_usuario)');
      qry.SQL.Add('values(:id_mesa, :cliente_comanda, :status, current_timestamp, :id_usuario)');
      qry.SQL.Add('returning id_comanda');

      qry.ParamByName('id_mesa').Value         := id_mesa;
      qry.ParamByName('cliente_comanda').Value := cliente_comanda;
      qry.ParamByName('status').Value          := StatusComanda[Integer(TStatusComanda.tscAberta)];
      qry.ParamByName('id_usuario').Value      := id_usuario;
      qry.Active := true;

      Result := qry.ToJSONObject;

      Self.Commit;

    except on ex:exception do
      begin
        Self.Rollback;
        raise Exception.Create(ex.Message);
      end;
    end;

  finally
    qry.Free;
  end;
end;


end.
