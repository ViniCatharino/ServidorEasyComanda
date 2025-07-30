unit Controllers.Produto;

interface

uses Horse,
     Horse.JWT,
     System.JSON,
     System.SysUtils,
     DAO.Produto,
     Controllers.Auth;

procedure RegistrarRotas;
procedure ListarCategorias(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure ListarProdutos(Req: THorseRequest; Res: THorseResponse; Next: TProc);
procedure ListarProdutosMaisVendidos(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

procedure RegistrarRotas;
begin
  THorse{.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims))) }
        .get('/categorias', ListarCategorias);

  THorse{.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))}
        .get('/categorias/:id_categoria/produtos', ListarProdutos);

  THorse{.AddCallback(HorseJWT(Controllers.Auth.SECRET, THorseJWTConfig.New.SessionClass(TMyClaims)))}
        .get('/produtos/maisvendidos', ListarProdutosMaisVendidos);

end;

procedure ListarCategorias(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOProduto: TDAOProduto;
begin
  DAOProduto := nil;
  try
    try
      DAOProduto := TDAOProduto.Create;

      Res.Send<TJSONArray>(DAOProduto.ListarCategorias());

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOProduto.Free;
  end;
end;

procedure ListarProdutosMaisVendidos(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOProduto: TDAOProduto;
begin
  DAOProduto := nil;
  try
    try
      DAOProduto := TDAOProduto.Create;

      Res.Send<TJSONArray>(DAOProduto.ListarProdutosMaisVendidos());

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOProduto.Free;
  end;
end;


procedure ListarProdutos(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  DAOProduto: TDAOProduto;
  id_categoria: integer;
  descricao: string;
begin
  DAOProduto := nil;
  try
    try
      DAOProduto := TDAOProduto.Create;

      id_categoria := Req.Params['id_categoria'].ToInteger;
      descricao    := Req.Query['descricao'];

      Res.Send<TJSONArray>(DAOProduto.ListarProdutos(id_categoria, descricao));

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    DAOProduto.Free;
  end;
end;


end.
