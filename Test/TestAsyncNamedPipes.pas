unit TestAsyncNamedPipes;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit
  being tested.

}

interface

uses
  TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  VCL.Forms,
  NamedPipes.Async,
  NamedPipes.Async.Classes,
  NamedPipes.PacketStream,
  System.Classes;

type
  // Test methods for class TNamedPipeClient

  TestTNamedPipeClient = class(TTestCase)
  strict private
    FServerReceivedData: TBytes;
    FServerReceivedCommand: Integer;

    FClientReceivedData: TBytes;
    FClientReceivedCommand: Integer;

    procedure OnServerRead(Sender: TObject; Pipe: HPIPE; Command: Integer; Data: TStream);
    procedure OnClientRead(Sender: TObject; Pipe: HPIPE; Command: Integer; Data: TStream);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSetPipe;
    procedure TestConnect;
    procedure TestWriteMessage;
    procedure TestWriteMessage1;
    procedure TestWriteMessage2;
    procedure TestWriteLongMessage;
    procedure TestInit;
    procedure TestInstance;
  end;

implementation

procedure TestTNamedPipeClient.OnClientRead(Sender: TObject; Pipe: HPIPE; Command: Integer; Data: TStream);
begin
  FClientReceivedCommand := Command;
  Data.Seek(0, soBeginning);
  SetLength(FClientReceivedData, Data.Size);
  Data.ReadBuffer(FClientReceivedData, 0, Length(FClientReceivedData));
end;

procedure TestTNamedPipeClient.OnServerRead(Sender: TObject; Pipe: HPIPE; Command: Integer; Data: TStream);
begin
  FServerReceivedCommand := Command;
  Data.Seek(0, soBeginning);
  SetLength(FServerReceivedData, Data.Size);
  Data.ReadBuffer(FServerReceivedData, 0, Length(FServerReceivedData));

  TNamedPipeServer.Instance.BroadcastMessage(Command, Data);
end;

procedure TestTNamedPipeClient.SetUp;
begin
  TNamedPipeClient.SetDefaultValues('.', 'TestPIPE');
  if not TNamedPipeServer.Instance.Active then
    begin
      TNamedPipeServer.Instance.PipeName := 'TestPIPE';
      TNamedPipeServer.Instance.Active := True;
    end;
  TNamedPipeServer.Instance.OnRead := OnServerRead;
  TNamedPipeClient.Instance.OnRead := OnClientRead;
end;

procedure TestTNamedPipeClient.TearDown;
begin
end;

procedure TestTNamedPipeClient.TestSetPipe;
var
  PipeName: string;
  ServerName: string;
begin
  PipeName := 'TestPIPE';
  ServerName := '.';
  // TODO: Setup method call parameters
  TNamedPipeClient.Instance.SetPipe(ServerName, PipeName);
  // TODO: Validate method results
  CheckEquals(PipeName, TNamedPipeClient.Instance.PipeName);
  CheckEquals(ServerName, TNamedPipeClient.Instance.ServerName);
end;

procedure TestTNamedPipeClient.TestConnect;
var
  ReturnValue: Boolean;
begin
  ReturnValue := TNamedPipeClient.Instance.Connect;
  // TODO: Validate method results
  CheckTrue(ReturnValue);
end;

procedure TestTNamedPipeClient.TestWriteLongMessage;
var
  ReturnValue: Boolean;
  Bytes: TBytes;
  i: Integer;
begin
  // TODO: Setup method call parameters
  FServerReceivedCommand := -1;
  FClientReceivedCommand := -1;
  SetLength(Bytes, 65535);
  for i := 0 to Length(Bytes)-1 do
    Bytes[i]:=LongRec(i).Bytes[0];
  ReturnValue := TNamedPipeClient.Instance.WriteMessage(2, Bytes);
  CheckTrue(ReturnValue);

  // TODO: Validate method results
  while FServerReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(2, FServerReceivedCommand);
  CheckEquals(Length(Bytes), Length(FServerReceivedData));
  for i := 0 to Length(Bytes) - 1 do
    CheckEquals(Bytes[i], FServerReceivedData[i]);


  while FClientReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(2, FClientReceivedCommand);
  CheckEquals(Length(Bytes), Length(FClientReceivedData));
  for i := 0 to Length(Bytes) - 1 do
    CheckEquals(Bytes[i], FClientReceivedData[i]);
end;

procedure TestTNamedPipeClient.TestWriteMessage;
var
  ReturnValue: Boolean;
  Stream: TStream;
  Buf: TBytes;
  i: Integer;
begin
  // TODO: Setup method call parameters
  FServerReceivedCommand := -1;
  FClientReceivedCommand := -1;
  Stream := TMemoryStream.Create;
  try
    Buf := [1, 2, 3];
    Stream.WriteBuffer(Buf, Length(Buf));
    Stream.Seek(0, soBeginning);
    ReturnValue := TNamedPipeClient.Instance.WriteMessage(1, Stream);
    CheckTrue(ReturnValue);
  finally
    Stream.Free;
  end;
  // TODO: Validate method results
  while FServerReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(1, FServerReceivedCommand);
  CheckEquals(Length(Buf), Length(FServerReceivedData));
  for i := 0 to Length(Buf) - 1 do
    CheckEquals(Buf[i], FServerReceivedData[i]);


  while FClientReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(1, FClientReceivedCommand);
  CheckEquals(Length(Buf), Length(FClientReceivedData));
  for i := 0 to Length(Buf) - 1 do
    CheckEquals(Buf[i], FClientReceivedData[i]);
end;

procedure TestTNamedPipeClient.TestWriteMessage1;
var
  ReturnValue: Boolean;
  Bytes: TBytes;
  i: Integer;
begin
  // TODO: Setup method call parameters
  FServerReceivedCommand := -1;
  FClientReceivedCommand := -1;
  Bytes := [8, 9, 3];
  ReturnValue := TNamedPipeClient.Instance.WriteMessage(2, Bytes);
  CheckTrue(ReturnValue);

  // TODO: Validate method results
  while FServerReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(2, FServerReceivedCommand);
  CheckEquals(Length(Bytes), Length(FServerReceivedData));
  for i := 0 to Length(Bytes) - 1 do
    CheckEquals(Bytes[i], FServerReceivedData[i]);


  while FClientReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(2, FClientReceivedCommand);
  CheckEquals(Length(Bytes), Length(FClientReceivedData));
  for i := 0 to Length(Bytes) - 1 do
    CheckEquals(Bytes[i], FClientReceivedData[i]);
end;

procedure TestTNamedPipeClient.TestWriteMessage2;
var
  ReturnValue: Boolean;
  Msg: string;
  msgBytes: TBytes;
  i: Integer;
begin
  // TODO: Setup method call parameters
  FServerReceivedCommand := -1;
  FClientReceivedCommand := -1;
  Msg := '��� �������� ��������� (or Test message) #3';

  ReturnValue := TNamedPipeClient.Instance.WriteMessage(3, Msg);
  // TODO: Validate method results
  CheckTrue(ReturnValue);

  msgBytes := TEncoding.UTF8.GetBytes(Msg);

  // TODO: Validate method results
  while FServerReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(3, FServerReceivedCommand);
  CheckEquals(Length(msgBytes), Length(FServerReceivedData));
  for i := 0 to Length(msgBytes) - 1 do
    CheckEquals(msgBytes[i], FServerReceivedData[i]);

  while FClientReceivedCommand = -1 do
    Application.ProcessMessages;
  CheckEquals(3, FClientReceivedCommand);
  CheckEquals(Length(msgBytes), Length(FClientReceivedData));
  for i := 0 to Length(msgBytes) - 1 do
    CheckEquals(msgBytes[i], FClientReceivedData[i]);
end;

procedure TestTNamedPipeClient.TestInit;
var
  DefaultPipeName: string;
  DefaultServerName: string;
begin
  DefaultServerName := '.'; // localhost
  DefaultPipeName := 'f12312asdf';
  // TODO: Setup method call parameters
  TNamedPipeClient.SetDefaultValues(DefaultServerName, DefaultPipeName);
  // TODO: Validate method results
  // CheckEquals(DefaultServerName, TNamedPipeClient.Instance.ServerName);
  // CheckEquals(DefaultPipeName, TNamedPipeClient.Instance.PipeName);
end;

procedure TestTNamedPipeClient.TestInstance;
var
  ReturnValue: TNamedPipeClient;
begin
  ReturnValue := TNamedPipeClient.Instance;
  // TODO: Validate method results
  CheckNotNull(ReturnValue);
end;

initialization

// Register any test cases with the test runner
RegisterTest(TestTNamedPipeClient.Suite);

end.