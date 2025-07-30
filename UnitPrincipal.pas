unit UnitPrincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TFrmPrincipal = class(TForm)
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FrmPrincipal: TFrmPrincipal;

implementation

{$R *.dfm}

uses Horse,
     Horse.Jhonson,
     Horse.CORS,
     Controllers.Usuario,
     Controllers.Mesa,
     Controllers.Produto,
     Controllers.Comanda,
     Controllers.LocalPreparo,
     Controllers.Pedido,
     Controllers.Adicional,
     Controllers.AdicionalItem,
     DataSet.Serialize.Config;


procedure TFrmPrincipal.FormShow(Sender: TObject);
begin
  THorse.Use(Jhonson());
  THorse.Use(CORS);

  TDataSetSerializeConfig.GetInstance.CaseNameDefinition      := cndLower;
  TDataSetSerializeConfig.GetInstance.Import.DecimalSeparator := '.';

  // Regitrar Rotas...
  Controllers.Usuario.RegistrarRotas;
  Controllers.Mesa.RegistrarRotas;
  Controllers.Produto.RegistrarRotas;
  Controllers.Comanda.RegistrarRotas;
  Controllers.LocalPreparo.RegistrarRotas;
  Controllers.Pedido.RegistrarRotas;
  Controllers.Adicional.RegistrarRotas;
  Controllers.AdicionalItem.RegistrarRotas;


  THorse.Listen(3001);
 end;

end.
