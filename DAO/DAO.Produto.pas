unit DAO.Produto;

interface

uses Firedac.Comp.Client,
     FireDAC.DApt,
     System.JSON,
     DataSet.Serialize,
     DAO.Connection,
     System.SysUtils;


type
  TDAOProduto = class(TDAOConnection)
  private

  public
    function ListarProdutosMaisVendidos: TJSONArray;
    function ListarCategorias(): TJSONArray;
    function ListarProdutos(id_categoria: integer; descricao: string): TJSONArray;
  end;

implementation

function TDAOProduto.ListarCategorias(): TJSONArray;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select * from produto_categoria');
    qry.Active := true;

    Result := qry.ToJSONArray;

  finally
    qry.Free;
  end;
end;

function TDAOProduto.ListarProdutosMaisVendidos(): TJSONArray;
var
  LQry: TFDQuery;
begin
  try
    LQry            := TFDQuery.Create(nil);
    LQry.Connection := Self.Connection;

    LQry.SQL.Add('SELECT                                                 ');
    LQry.SQL.Add('    p.id_produto,                                      ');
    LQry.SQL.Add('    p.descricao,                                       ');
    LQry.SQL.Add('    p.preco,                                           ');
    LQry.SQL.Add('    p.id_categoria,                                    ');
    LQry.SQL.Add('    SUM(pi.qtd) AS total_vendido                       ');
    LQry.SQL.Add('FROM                                                   ');
    LQry.SQL.Add('    pedido_item pi                                     ');
    LQry.SQL.Add('JOIN                                                   ');
    LQry.SQL.Add('    produto p ON pi.id_produto = p.id_produto          ');
    LQry.SQL.Add('GROUP BY                                               ');
    LQry.SQL.Add('    p.id_produto, p.descricao, p.preco ,p.id_categoria ');
    LQry.SQL.Add('ORDER BY                                               ');
    LQry.SQL.Add('    total_vendido DESC                                 ');
    LQry.SQL.Add('ROWS 1 TO 10;                                          ');
    LQry.Active := true;

    Result := LQry.ToJSONArray;

  finally
    LQry.Free;
  end;
end;



function TDAOProduto.ListarProdutos(id_categoria: integer; descricao: string): TJSONArray;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select * from produto             ');
    qry.SQL.Add('where id_categoria = :id_categoria');

    if descricao <> '' then
    begin
      qry.SQL.Add('and descricao like :descricao');
      qry.ParamByName('descricao').Value := '%' + descricao + '%';
    end;

    qry.SQL.Add('order by descricao');
    qry.ParamByName('id_categoria').Value := id_categoria;
    qry.Active := true;

    Result := qry.ToJSONArray;

  finally
    qry.Free;
  end;
end;


end.
