unit ufmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, uNamedPipesExchange, Vcl.StdCtrls;

type
  TForm12 = class(TForm)
    btnSendLittleData1: TButton;
    btnSendLittleData2: TButton;
    btnSendBigData1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSendLittleData1Click(Sender: TObject);
    procedure btnSendLittleData2Click(Sender: TObject);
    procedure btnSendBigData1Click(Sender: TObject);
  private
    { Private declarations }
    FClient: TPipeClient;
    FThread: TThread;
  public
    { Public declarations }
  end;

var
  Form12: TForm12;

implementation

{$R *.dfm}

type
  TServerThread = class(TThread)
  private
    FServer: TPIPEServer;
    procedure OnReadFromPipe(Sender: TObject; PipeHandle: THandle; IncommingValue: TStream; OutgoingValue: TStream);
    procedure OnIdle(Sender: TObject);
  protected
    procedure Execute; override;
  end;

  { TServerThread }

procedure TServerThread.Execute;
begin
  FServer := TPIPEServer.Create('LocalhostPipeTest');
  try
    FServer.OnReadFromPipe := OnReadFromPipe;
    FServer.OnIdle := OnIdle;
    FServer.Active := True;
  finally
    FServer.Free;
  end;
end;

procedure TServerThread.OnIdle(Sender: TObject);
begin
  if Terminated then
    TPIPEServer(Sender).Active := False;
end;

procedure TServerThread.OnReadFromPipe(Sender: TObject; PipeHandle: THandle; IncommingValue, OutgoingValue: TStream);
var
  Cmd: integer;
begin
  IncommingValue.Read(Cmd, SizeOf(integer));
  case Cmd of
    0:
      OutgoingValue.Size := 100;
    1:
      OutgoingValue.Size := 65535 * 4;
    2:
      OutgoingValue.CopyFrom(IncommingValue, 0);
  end;
end;

procedure TForm12.btnSendBigData1Click(Sender: TObject);
var
  SendStream, ReceiveStream: TMemoryStream;
  Cmd: integer;
  i: integer;
begin
  SendStream := TMemoryStream.Create;
  try
    ReceiveStream := TMemoryStream.Create;
    try
      Cmd := 2;
      SendStream.Write(Cmd, SizeOf(integer));
      for i := 0 to 65535 do
        SendStream.Write(Cmd, SizeOf(integer));
      FClient.SendData(SendStream, ReceiveStream);

      Caption := 'Received stream size = ' + IntToStr(ReceiveStream.Size) + BoolToStr(SendStream.Size = ReceiveStream.Size);
    finally
      ReceiveStream.Free;
    end;
  finally
    SendStream.Free;
  end;
end;

procedure TForm12.btnSendLittleData1Click(Sender: TObject);
var
  SendStream, ReceiveStream: TMemoryStream;
  Cmd: integer;
begin
  SendStream := TMemoryStream.Create;
  try
    ReceiveStream := TMemoryStream.Create;
    try
      Cmd := 0;
      SendStream.Write(Cmd, SizeOf(integer));
      FClient.SendData(SendStream, ReceiveStream);

      Caption := 'Received stream size = ' + IntToStr(ReceiveStream.Size);
    finally
      ReceiveStream.Free;
    end;
  finally
    SendStream.Free;
  end;
end;

procedure TForm12.btnSendLittleData2Click(Sender: TObject);
var
  SendStream, ReceiveStream: TMemoryStream;
  Cmd: integer;
begin
  SendStream := TMemoryStream.Create;
  try
    ReceiveStream := TMemoryStream.Create;
    try
      Cmd := 1;
      SendStream.Write(Cmd, SizeOf(integer));
      FClient.SendData(SendStream, ReceiveStream);

      Caption := 'Received stream size = ' + IntToStr(ReceiveStream.Size);
    finally
      ReceiveStream.Free;
    end;
  finally
    SendStream.Free;
  end;
end;

procedure TForm12.FormCreate(Sender: TObject);
begin
  FThread := TServerThread.Create(False);
  while not FThread.Started do
    Sleep(100);

  FClient := TPipeClient.Create('.', 'LocalhostPipeTest');
  FClient.Active := True;
end;

procedure TForm12.FormDestroy(Sender: TObject);
begin
  FClient.Free;
  FThread.Free;
end;

end.
