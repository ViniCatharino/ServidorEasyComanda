unit DAO.Usuario;

interface

uses Firedac.Comp.Client,
     FireDAC.DApt,
     System.JSON,
     DataSet.Serialize,
     DAO.Connection;


type
  TDAOUsuario = class(TDAOConnection)
  private

  public
    function Login(login, senha: string): TJSONObject;
    function DoLogin(ANome, ALogin, ASenha: string) : TJSONObject;
  end;

implementation

{ TDAOUsuario }

function TDAOUsuario.DoLogin(ANome, ALogin, ASenha: string): TJSONObject;
var
  qry: TFDQuery;
begin
  try
    try
      qry := TFDQuery.Create(nil);
      qry.Connection := Self.Connection;

      qry.SQL.Add('INSERT INTO usuario (NOME, LOGIN, SENHA) VALUES (:NOME,:LOGIN,:SENHA)');
      qry.ParamByName('login').AsString := Alogin;
      qry.ParamByName('senha').AsString := Asenha;
      qry.ParamByName('nome').AsString  := ANome;
      qry.ExecSQL;
      Result := qry.ToJSONObject;
    except

    end;

  finally
    qry.Free;
  end;
end;

function TDAOUsuario.Login(login, senha: string): TJSONObject;
var
  qry: TFDQuery;
begin
  try
    qry := TFDQuery.Create(nil);
    qry.Connection := Self.Connection;

    qry.SQL.Add('select id_usuario, nome, login from usuario');
    qry.SQL.Add('where login = :login and senha = :senha');
    qry.ParamByName('login').Value := login;
    qry.ParamByName('senha').Value := senha;
    qry.Active := true;

    Result := qry.ToJSONObject;

  finally
    qry.Free;
  end;
end;



end.
