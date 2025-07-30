unit DAO.Pedido;

interface

uses Firedac.Comp.Client,
     FireDAC.DApt,
     System.JSON,
     DataSet.Serialize,
     DAO.Connection,
     System.SysUtils,
     System.Classes,
     uImpressao,
     Core.Utils.Tipos,
     System.Generics.Collections;


type
  TDAOPedido = class(TDAOConnection)
  private
    procedure AtualizarStatusPedido(id_pedido: integer);
    procedure ImprimirPedido(id_pedido: integer);
    procedure ImprimirCancelamentoItem(id_pedido, id_item, id_usuario: integer);
  public
    function ListarPedidos(status_ped, status_item_not: string; id_local: integer): TJSONArray;
    function InserirPedido(id_comanda, id_usuario: integer; itens, itensAdicionais: TJSONArray): TJSONObject;
    procedure ExcluirItem(id_pedido, id_item, id_usuario: integer);
    procedure EditarStatusItem(id_pedido, id_item: integer; status: string);
  end;

implementation

procedure TDAOPedido.AtualizarStatusPedido(id_pedido: integer);
var
  qry     : TFDQuery;
  LStatus : string;
  LTotalItens: currency;
  LTotalItensAdicionais: currency;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select id_item from pedido_item');
    qry.SQL.Add('where id_pedido = :id_pedido and status <> :status');
    qry.ParamByName('id_pedido').Value := id_pedido;
    qry.ParamByName('status').Value    := StatusPedido[Integer(TStatusPedido.tspEntregue)];
    qry.Active := true;

    if qry.RecordCount > 0 then
      LStatus := StatusPedido[Integer(TStatusPedido.tspAberto)]
    else
      LStatus := StatusPedido[Integer(TStatusPedido.tspEntregue)];

    qry.Active := false;
    qry.SQL.Clear;
    qry.SQL.Add('select sum(i.qtd * o.preco) totalItens          ');
    qry.SQL.Add('from pedido_item i                              ');
    qry.SQL.Add('join produto o on (o.id_produto = i.id_produto) ');
    qry.SQL.Add('where i.id_pedido = :id_pedido                  ');
    qry.ParamByName('id_pedido').Value := id_pedido;
    qry.Open;

    LTotalItens := qry.FieldByName('totalItens').AsCurrency;


    qry.Active := false;
    qry.SQL.Clear;
    qry.SQL.Add('Select                                                          ');
    qry.SQL.Add('    sum(ai.valor * ai.quantidade) as totalAdicionais            ');
    qry.SQL.Add('from                                                            ');
    qry.SQL.Add('    pedido p                                                    ');
    qry.SQL.Add('inner join pedido_item ip on ip.id_pedido=p.id_pedido           ');
    qry.SQL.Add('inner join produto pr on pr.id_produto = ip.id_produto          ');
    qry.SQL.Add('inner join adicionais_item ai on ai.id_item_pedido = ip.id_item ');
    qry.SQL.Add('inner join adicional adc on adc.id_adicional = ai.id_adicional  ');
    qry.SQL.Add('where p.id_pedido=:id_pedido                                    ');
    qry.ParamByName('id_pedido').Value := id_pedido;
    qry.Open;

    LTotalItensAdicionais := qry.FieldByName('totalAdicionais').AsCurrency;

    qry.Active := false;
    qry.SQL.Clear;
    qry.SQL.Add('update pedido set status = :status, ');
    qry.SQL.Add('       vl_total = :valor_total      ');
    qry.SQL.Add('where id_pedido = :id_pedido        ');
    qry.ParamByName('id_pedido').Value        := id_pedido;
    qry.ParamByName('valor_total').AsCurrency := (LTotalItens + LTotalItensAdicionais);
    qry.ParamByName('status').Value           := LStatus;
    qry.ExecSQL;



  finally
    qry.Free;
  end;
end;

function TDAOPedido.ListarPedidos(status_ped, status_item_not: string; id_local: integer): TJSONArray;
var
  qry: TFDQuery;
  i: integer;
  removed_ped: TJSONValue;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    // Pedidos...
    qry.SQL.Add('select p.*, m.numero_mesa, c.cliente_comanda, u.nome,  ');
    qry.SQL.Add('format_minutes(datediff(minute, dt_pedido, current_timestamp)) as tempo');
    qry.SQL.Add('from pedido p');
    qry.SQL.Add('join comanda c on (c.id_comanda = p.id_comanda)');
    qry.SQL.Add('join mesa m on (m.id_mesa = c.id_mesa)');
    qry.SQL.Add('join usuario u on (u.id_usuario = p.id_usuario)');

    if status_ped <> '' then
    begin
      qry.SQL.Add('where p.status = :status');
      qry.ParamByName('status').Value := status_ped;
    end;

    qry.SQL.Add('order by p.id_pedido');
    qry.Active := true;

    Result := qry.ToJSONArray;


    // Itens dos pedidos...
    for i := Result.Size - 1 downto 0 do
    begin
      qry.Active := false;
      qry.SQL.Clear;
      qry.SQL.Add('select i.*, p.descricao');
      qry.SQL.Add('from pedido_item i');
      qry.SQL.Add('join produto p on (p.id_produto = i.id_produto)');
      qry.SQL.Add('join produto_categoria c on (c.id_categoria = p.id_categoria)');
      qry.SQL.Add('where i.id_pedido = :id_pedido');
      qry.ParamByName('id_pedido').Value := TJsonObject(Result[i]).GetValue<integer>('id_pedido');

      if id_local > 0 then
      begin
        qry.SQL.Add('and c.id_local = :id_local');
        qry.ParamByName('id_local').Value := id_local;
      end;

      if status_item_not <> '' then
      begin
        qry.SQL.Add('and i.status <> :status_item_not');
        qry.ParamByName('status_item_not').Value := status_item_not;
      end;

      qry.SQL.Add('order by p.descricao');
      qry.Active := true;

      if qry.RecordCount = 0 then
      begin
        removed_ped := Result.Remove(i);
        removed_ped.Free;
      end
      else
        TJsonObject(Result[i]).AddPair('itens', qry.ToJSONArray);
    end;

  finally
    qry.Free;
  end;
end;

procedure TDAOPedido.ImprimirPedido(id_pedido: integer);
var
  qryLocal, qryItem: TFDQuery;
  texto: TStringList;
begin
  try
    qryLocal := TFDQuery.Create(nil);
    qryLocal.Connection := Self.Connection;

    qryItem := TFDQuery.Create(nil);
    qryItem.Connection := Self.Connection;

    // Lista dos locais e suas impressoras...
    qryLocal.SQL.Add('select distinct l.id_local, l.nome, l.impressora');
    qryLocal.SQL.Add('from pedido_item i');
    qryLocal.SQL.Add('join produto o on (o.id_produto = i.id_produto)');
    qryLocal.SQL.Add('join produto_categoria c on (c.id_categoria = o.id_categoria)');
    qryLocal.SQL.Add('join local_preparo l on (l.id_local = c.id_local)');
    qryLocal.SQL.Add('where i.id_pedido = :id_pedido');
    qryLocal.ParamByName('id_pedido').Value := id_pedido;
    qryLocal.Active := true;

    while not qryLocal.Eof do
    begin
        if qryLocal.FieldByName('impressora').AsString <> '' then
        begin
            qryItem.Active := false;
            qryItem.SQl.Clear;
            qryItem.SQL.Add('select l.nome, m.numero_mesa, c.cliente_comanda, i.qtd, o.descricao, i.obs');
            qryItem.SQL.Add('from pedido p');
            qryItem.SQL.Add('join comanda c on (c.id_comanda = p.id_comanda)');
            qryItem.SQL.Add('join mesa m on (m.id_mesa = c.id_mesa)');
            qryItem.SQL.Add('join pedido_item i on  (i.id_pedido = p.id_pedido)');
            qryItem.SQL.Add('join produto o on (o.id_produto = i.id_produto)');
            qryItem.SQL.Add('join produto_categoria t on (t.id_categoria = o.id_categoria)');
            qryItem.SQL.Add('join local_preparo l on (l.id_local = t.id_local)');
            qryItem.SQL.Add('where p.id_pedido = :id_pedido');
            qryItem.SQL.Add('and l.id_local = :id_local');
            qryItem.SQL.Add('order by o.descricao');
            qryItem.ParamByName('id_pedido').Value := id_pedido;
            qryItem.ParamByName('id_local').Value := qryLocal.FieldByName('id_local').AsInteger;
            qryItem.Active := true;


            // Cabecalho da impressao
            texto := TStringList.Create;
            texto.Add(qryItem.FieldByName('nome').AsString);
            texto.Add('******************************');
            texto.Add('Mesa: ' + qryItem.FieldByName('numero_mesa').AsString);
            texto.Add('Comanda: ' + qryItem.FieldByName('cliente_comanda').AsString);
            texto.Add('');

            // Itens da impressao
            while NOT qryItem.Eof do
            begin
                texto.Add(FormatFloat('00', qryItem.FieldByName('qtd').AsInteger) + ' ' +
                                            qryItem.FieldByName('descricao').AsString);

                if qryItem.FieldByName('obs').AsString <> '' then
                  texto.Add('(' + qryItem.FieldByName('obs').AsString + ')');

                texto.Add('');

                qryItem.Next;
            end;

            texto.Add('.');
            texto.Add('.');
            texto.Add('.');

            Impressao(texto, qryLocal.FieldByName('impressora').AsString);
            texto.Free;
        end;


        qryLocal.Next;
    end;

  finally
    qryLocal.Free;
    qryItem.Free;
  end;
end;

procedure TDAOPedido.ImprimirCancelamentoItem(id_pedido, id_item, id_usuario: integer);
var
  qryItem: TFDQuery;
  texto: TStringList;
begin
  try
    qryItem := TFDQuery.Create(nil);
    qryItem.Connection := Self.Connection;

    qryItem.Active := false;
    qryItem.SQl.Clear;
    qryItem.SQL.Add('select l.impressora, l.nome, m.numero_mesa, c.cliente_comanda, i.qtd, o.descricao, i.obs, u.nome as usuario');
    qryItem.SQL.Add('from pedido p');
    qryItem.SQL.Add('join comanda c on (c.id_comanda = p.id_comanda)');
    qryItem.SQL.Add('join mesa m on (m.id_mesa = c.id_mesa)');
    qryItem.SQL.Add('join pedido_item i on  (i.id_pedido = p.id_pedido)');
    qryItem.SQL.Add('join produto o on (o.id_produto = i.id_produto)');
    qryItem.SQL.Add('join produto_categoria t on (t.id_categoria = o.id_categoria)');
    qryItem.SQL.Add('join local_preparo l on (l.id_local = t.id_local)');
    qryItem.SQL.Add('join usuario u on (u.id_usuario = :id_usuario)');
    qryItem.SQL.Add('where i.id_pedido = :id_pedido');
    qryItem.SQL.Add('and i.id_item = :id_item');
    qryItem.SQL.Add('order by o.descricao');
    qryItem.ParamByName('id_pedido').Value := id_pedido;
    qryItem.ParamByName('id_item').Value := id_item;
    qryItem.ParamByName('id_usuario').Value := id_usuario;
    qryItem.Active := true;

    // Caso nao tenha impressora
    if qryItem.FieldByName('impressora').AsString = '' then
      exit;

    // Cabecalho da impressao
    texto := TStringList.Create;
    texto.Add('CANCELAMENTO');
    texto.Add('******************************');
    texto.Add('Mesa: ' + qryItem.FieldByName('numero_mesa').AsString);
    texto.Add('Comanda: ' + qryItem.FieldByName('cliente_comanda').AsString);
    texto.Add('Usuário: ' + qryItem.FieldByName('usuario').AsString);
    texto.Add('');
    texto.Add('Item cancelado:');

    texto.Add(FormatFloat('00', qryItem.FieldByName('qtd').AsInteger) + ' ' +
                                qryItem.FieldByName('descricao').AsString);

    if qryItem.FieldByName('obs').AsString <> '' then
      texto.Add('(' + qryItem.FieldByName('obs').AsString + ')');

    texto.Add('');
    texto.Add('.');
    texto.Add('.');
    texto.Add('.');

    Impressao(texto, qryItem.FieldByName('impressora').AsString);
    texto.Free;

  finally
    qryItem.Free;
  end;
end;

function TDAOPedido.InserirPedido(id_comanda, id_usuario: integer; itens, itensAdicionais: TJSONArray): TJSONObject;

  procedure InserirItemAdicional(AIdItem, AIdItemTemp: integer);
  var
    LQryItem       : TFDQuery;
    LItemAdicional : integer;
  begin
    LQryItem := TFDQuery.Create(nil);
    LQryItem.Connection := Self.Connection;
    try
      try
        for LItemAdicional := 0 to itensAdicionais.Size -1 do
        begin
          if itensAdicionais[LItemAdicional].GetValue<integer>('id_item') = AIdItemTemp then
          begin
            LQryItem.Active := false;
            LQryItem.SQL.Clear;
            LQryItem.SQL.Text :=
            'insert into adicionais_item (id_item_pedido, id_adicional, quantidade, valor)' +
            'values(:id_item_pedido, :id_adicional, :quantidade, :valor)                  ' ;

            LQryItem.ParamByName('id_item_pedido').Value := AIdItem;
            LQryItem.ParamByName('id_adicional').Value   := itensAdicionais[LItemAdicional].GetValue<integer>('id_adicional');
            LQryItem.ParamByName('quantidade').Value     := itensAdicionais[LItemAdicional].GetValue<double>('quantidade');
            LQryItem.ParamByName('valor').Value          := itensAdicionais[LItemAdicional].GetValue<Double>('valor', 0);
            LQryItem.ExecSQL;
          end;
        end;
      except
        on e:exception do
        begin
          raise Exception.Create('Erro ao gravar adicionais: ' + e.Message);
        end;
      end;
    finally
      FreeAndNil(LQryItem);
    end;
  end;


  procedure InserirItemPedido(AIdPedido: integer);
  var
    LQryItem       : TFDQuery;
    LItem          : integer;
    LIdItem        : integer;
    LIdTemp        : integer;
    LItemAdicional : integer;
  begin
    LQryItem := TFDQuery.Create(nil);
    LQryItem.Connection := Self.Connection;
    try
      try
        for LItem := 0 to itens.Size - 1 do
        begin
          LQryItem.Active := false;
          LQryItem.SQL.Clear;
          LQryItem.SQL.Text :=
          'insert into pedido_item(id_pedido, id_produto, qtd, status, obs) ' +
          'values(:id_pedido, :id_produto, :qtd, :status, :obs)             ' +
          'Returning id_item                                                ' ;
          LQryItem.ParamByName('id_pedido').Value  := AIdPedido;
          LQryItem.ParamByName('id_produto').Value := itens[LItem].GetValue<integer>('id_produto');
          LQryItem.ParamByName('qtd').Value        := itens[LItem].GetValue<integer>('qtd');
          LQryItem.ParamByName('status').Value     := StatusPedido[Integer(TStatusPedido.tspAberto)];
          LQryItem.ParamByName('obs').Value        := itens[LItem].GetValue<string>('obs', '');
          LQryItem.open;

          LIdItem := LQryItem.FieldByName('id_item').AsInteger;
          LIdTemp := itens[LItem].GetValue<integer>('id_item');

          InserirItemAdicional(LidItem, LIdTemp);
        end;
      except
        on e:exception do
        begin
          raise Exception.Create('Erro ao gravar Itens: ' + e.Message);
        end;
      end;
    finally
      FreeAndNil(LQryItem);
    end;
  end;



var
  qry                : TFDQuery;
  LQryItensAdicional : TFDQuery;
  LItem              : integer;
  LItemAdicional     : integer;
  LIdPedido          : integer;
  LIdItem            : integer;
  Lid_item           : Integer;
  Lid_temp           : Integer;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    try
      Self.StartTransaction;

      qry.Active := False;
      qry.SQL.Add('insert into pedido(id_comanda, status, dt_pedido, id_usuario, vl_total) ');
      qry.SQL.Add('values(:id_comanda, :status, current_timestamp, :id_usuario, 0)         ');
      qry.SQL.Add('returning id_pedido                                                     ');

      qry.ParamByName('id_comanda').Value := id_comanda;
      qry.ParamByName('status').Value     := StatusPedido[Integer(TStatusPedido.tspAberto)];
      qry.ParamByName('id_usuario').Value := id_usuario;
      qry.open;

      LIdPedido := qry.FieldByName('id_pedido').AsInteger;
      Result := qry.ToJSONObject;

      InserirItemPedido(LIdPedido);


      // Calcula total pedido...
      AtualizarStatusPedido(LIdPedido);

      // Impressao dos itens...
      ImprimirPedido(LIdPedido);

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

procedure TDAOPedido.ExcluirItem(id_pedido, id_item, id_usuario: integer);
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    try
      Self.StartTransaction;


      // Imprimir a etiqueta de exclusao com dados do usuario...
      ImprimirCancelamentoItem(id_pedido, id_item, id_usuario);


      qry.SQL.Add('delete from pedido_item');
      qry.SQL.Add('where id_item = :id_item and id_pedido = :id_pedido');
      qry.ParamByName('id_item').Value   := id_item;
      qry.ParamByName('id_pedido').Value := id_pedido;
      qry.ExecSQL;


      // Atualiza status pedido...
      AtualizarStatusPedido(id_pedido);


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

procedure TDAOPedido.EditarStatusItem(id_pedido, id_item: integer; status: string);
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    try
      Self.StartTransaction;

      qry.SQL.Add('update pedido_item set status = :status');
      qry.SQL.Add('where id_item = :id_item and id_pedido = :id_pedido');
      qry.ParamByName('status').Value    := status;
      qry.ParamByName('id_item').Value   := id_item;
      qry.ParamByName('id_pedido').Value := id_pedido;
      qry.ExecSQL;


      // Atualiza status pedido...
      AtualizarStatusPedido(id_pedido);


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
