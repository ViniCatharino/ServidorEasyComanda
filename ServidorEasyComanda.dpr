program ServidorEasyComanda;

uses
  Vcl.Forms,
  UnitPrincipal in 'UnitPrincipal.pas' {FrmPrincipal},
  Controllers.Usuario in 'Controllers\Controllers.Usuario.pas',
  DAO.Usuario in 'DAO\DAO.Usuario.pas',
  DAO.Connection in 'DAO\DAO.Connection.pas',
  uMD5 in 'Utils\uMD5.pas',
  Controllers.Mesa in 'Controllers\Controllers.Mesa.pas',
  DAO.Mesa in 'DAO\DAO.Mesa.pas',
  Controllers.Produto in 'Controllers\Controllers.Produto.pas',
  DAO.Produto in 'DAO\DAO.Produto.pas',
  Controllers.Comanda in 'Controllers\Controllers.Comanda.pas',
  DAO.Comanda in 'DAO\DAO.Comanda.pas',
  Controllers.LocalPreparo in 'Controllers\Controllers.LocalPreparo.pas',
  DAO.LocalPreparo in 'DAO\DAO.LocalPreparo.pas',
  DAO.Pedido in 'DAO\DAO.Pedido.pas',
  Controllers.Pedido in 'Controllers\Controllers.Pedido.pas',
  Controllers.Auth in 'Controllers\Controllers.Auth.pas',
  uImpressao in 'Utils\uImpressao.pas',
  Core.Utils.Tipos in '..\Core\Utils\Core.Utils.Tipos.pas',
  DAO.Adicional in 'DAO\DAO.Adicional.pas',
  Controllers.Adicional in 'Controllers\Controllers.Adicional.pas',
  Controllers.AdicionalItem in 'Controllers\Controllers.AdicionalItem.pas',
  DAO.AdicionalItem in 'DAO\DAO.AdicionalItem.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := true;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmPrincipal, FrmPrincipal);
  Application.Run;
end.
