unit TestuNamedPipesExchange;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  TestFramework, System.Classes, FWIOCompletionPipes, System.Generics.Collections,
  System.SysUtils, uNamedPipesExchange;

type
  // Test methods for class TAbstractPipeData

  TestTAbstractPipeData = class(TTestCase)
  strict private
    FAbstractPipeData: TAbstractPipeData;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;
  // Test methods for class TIncommingPipeData

  TestTIncommingPipeData = class(TTestCase)
  strict private
    FIncommingPipeData: TIncommingPipeData;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWriteData;
    procedure TestWriteData2;
    procedure TestWriteData3;
  end;
  // Test methods for class TOutgoingPipeData

  TestTOutgoingPipeData = class(TTestCase)
  strict private
    FOutgoingPipeData: TOutgoingPipeData;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPrepareForOutgoing;
  end;
  // Test methods for class TPipeDataDictionary

  TestTPipeDataDictionary = class(TTestCase)
  strict private
    FPipeDataDictionary: TPipeDataDictionary;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;
  // Test methods for class TPIPEServer

  TestTPIPEServer = class(TTestCase)
  strict private
    FPIPEServer: TPIPEServer;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;
  // Test methods for class TPipeClient

  TestTPipeClient = class(TTestCase)
  strict private
    FPipeClient: TPipeClient;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSendData;
  end;

implementation

procedure TestTAbstractPipeData.SetUp;
begin
  FAbstractPipeData := TAbstractPipeData.Create;
end;

procedure TestTAbstractPipeData.TearDown;
begin
  FAbstractPipeData.Free;
  FAbstractPipeData := nil;
end;

procedure TestTIncommingPipeData.SetUp;
begin
  FIncommingPipeData := TIncommingPipeData.Create;
end;

procedure TestTIncommingPipeData.TearDown;
begin
  FIncommingPipeData.Free;
  FIncommingPipeData := nil;
end;

procedure TestTIncommingPipeData.TestWriteData;
var
  Buf: TBytes;

  OutData: TOutgoingPipeData;
begin
  // TODO: Setup method call parameters

  OutData:=TOutgoingPipeData.Create;
  try
    SetLength(Buf, 20);
    FillChar(Buf[0], Length(Buf), $FF);
    OutData.DataStream.Write(Buf, Length(Buf));
    OutData.PrepareForOutgoing(pcNewData);

    SetLength(Buf, 0);
    OutData.ReadData(Buf, MaxBuffSize);
    CheckTrue(OutData.IsSended);

    FIncommingPipeData.WriteData(Buf);

    CheckTrue(FIncommingPipeData.IsReceived);
    CheckEquals(20, FIncommingPipeData.DataStream.Size);
  // TODO: Validate method results
  finally
    OutData.Free;
  end;
end;

procedure TestTIncommingPipeData.TestWriteData2;
var
  Buf: TBytes;
  OutData: TOutgoingPipeData;
begin
  OutData:=TOutgoingPipeData.Create;
  try
    SetLength(Buf, MaxBuffSize*2);
    FillChar(Buf[0], Length(Buf), $FF);
    OutData.DataStream.Write(Buf, Length(Buf));
    OutData.PrepareForOutgoing(pcNewData);

    SetLength(Buf, 0);
    OutData.ReadData(Buf, MaxBuffSize);
    CheckFalse(OutData.IsSended);

    FIncommingPipeData.WriteData(Buf);

    CheckFalse(FIncommingPipeData.IsReceived);
  // TODO: Validate method results
  finally
    OutData.Free;
  end;
end;

procedure TestTIncommingPipeData.TestWriteData3;
var
  Buf: TBytes;
  OutData: TOutgoingPipeData;
begin
  OutData:=TOutgoingPipeData.Create;
  try
    SetLength(Buf, MaxBuffSize*5);
    FillChar(Buf[0], Length(Buf), $FF);
    OutData.DataStream.Write(Buf, Length(Buf));
    OutData.PrepareForOutgoing(pcNewData);

    while not OutData.IsSended do
      begin
        SetLength(Buf, 0);
        OutData.ReadData(Buf, MaxBuffSize);

        FIncommingPipeData.WriteData(Buf);
      end;

    CheckTrue(FIncommingPipeData.IsReceived);
    CheckEquals(MaxBuffSize*5, FIncommingPipeData.DataStream.Size);
  // TODO: Validate method results
  finally
    OutData.Free;
  end;
end;

procedure TestTOutgoingPipeData.SetUp;
begin
  FOutgoingPipeData := TOutgoingPipeData.Create;
end;

procedure TestTOutgoingPipeData.TearDown;
begin
  FOutgoingPipeData.Free;
  FOutgoingPipeData := nil;
end;

procedure TestTOutgoingPipeData.TestPrepareForOutgoing;
var
  AHeaderCommand: TPipeCommand;
begin
  // TODO: Setup method call parameters
  AHeaderCommand:=pcNewData;
  FOutgoingPipeData.PrepareForOutgoing(AHeaderCommand);
  CheckTrue(FOutgoingPipeData.Header.Command = AHeaderCommand);
  CheckEquals(FOutgoingPipeData.DataStream.Size, FOutgoingPipeData.Header.DataSize);
  CheckEquals(0, FOutgoingPipeData.DataStream.Size);
  CheckFalse(FOutgoingPipeData.IsSended);
  // TODO: Validate method results

  FOutgoingPipeData.DataStream.Size:=100;
  FOutgoingPipeData.PrepareForOutgoing(AHeaderCommand);
  CheckEquals(FOutgoingPipeData.DataStream.Size, FOutgoingPipeData.Header.DataSize);
  CheckEquals(100, FOutgoingPipeData.DataStream.Size);
  CheckFalse(FOutgoingPipeData.IsSended);
end;

procedure TestTPipeDataDictionary.SetUp;
begin
  FPipeDataDictionary := TPipeDataDictionary.Create;
end;

procedure TestTPipeDataDictionary.TearDown;
begin
  FPipeDataDictionary.Free;
  FPipeDataDictionary := nil;
end;

procedure TestTPIPEServer.SetUp;
begin
  FPIPEServer := TPIPEServer.Create('TestPipe');
end;

procedure TestTPIPEServer.TearDown;
begin
  FPIPEServer.Free;
  FPIPEServer := nil;
end;

procedure TestTPipeClient.SetUp;
begin
  FPipeClient := TPipeClient.Create('localhost', 'TestPipe');
end;

procedure TestTPipeClient.TearDown;
begin
  FPipeClient.Free;
  FPipeClient := nil;
end;

procedure TestTPipeClient.TestSendData;
var
  ReceiveStream: TStream;
  SendStream: TStream;
begin
  // TODO: Setup method call parameters
  FPipeClient.SendData(SendStream, ReceiveStream);
  // TODO: Validate method results
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTAbstractPipeData.Suite);
  RegisterTest(TestTIncommingPipeData.Suite);
  RegisterTest(TestTOutgoingPipeData.Suite);
  RegisterTest(TestTPipeDataDictionary.Suite);
  RegisterTest(TestTPIPEServer.Suite);
  RegisterTest(TestTPipeClient.Suite);
end.

