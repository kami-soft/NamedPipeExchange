program ProjectNamedPipesExchange;

uses
  Vcl.Forms,
  ufmMain in 'ufmMain.pas' {Form12},
  uNamedPipesExchange in 'uNamedPipesExchange.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown:=True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm12, Form12);
  Application.Run;
end.
