unit NamedPipes.Async;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  NamedPipes.PacketStream,
  NamedPipes.Async.Classes;

type
  TReadPipeEvent = procedure(Sender: TObject; Pipe: HPIPE; Command: Integer; Data: TStream) of object;

  TNamedPipeClient = class(TObject)
  strict private
  class var
    FDefaultServerName: string;
    FDefaultPipeName: string;
    FInstance: TNamedPipeClient;

    class constructor Create;
    class destructor Destroy;
  strict private
    FPipeClient: TPipeClient;
    FCurrentData: TInPacketStream;
    FOnRead: TReadPipeEvent;

    procedure OnReadFromPipe(Sender: TObject; Pipe: HPIPE; Stream: TStream);

    function GetPipeName: string;
    function GetServerName: string;

    function IntWriteMessage(Command: Integer; OutStream: TOutPacketStream): Boolean;
  public
    constructor Create(const ServerName, PipeName: string);
    destructor Destroy; override;

    procedure SetPipe(const ServerName, PipeName: string);

    function Connect: Boolean;
    function WriteMessage(Command: Integer; Stream: TStream): Boolean; overload;
    function WriteMessage(Command: Integer; const ABytes: TBytes): Boolean; overload;
    function WriteMessage(Command: Integer; const Msg: string): Boolean; overload;

    class procedure SetDefaultValues(const DefaultServerName, DefaultPipeName: string);
    class function Instance: TNamedPipeClient;

    property ServerName: string read GetServerName;
    property PipeName: string read GetPipeName;
    property OnRead: TReadPipeEvent read FOnRead write FOnRead;
  end;

  TClientInfo = record
    Description: string;
    Data: Pointer;
  end;

  TNamedPipeServer = class(TObject)
  strict private
    class var FInstance: TNamedPipeServer;

    class destructor Destroy;
  strict private
    FServer: TPipeServer;
    FServerReadData: TObjectDictionary<HPIPE, TInPacketStream>;
    FClients: TDictionary<HPIPE, TClientInfo>;

    FOnClientConnect: TOnPipeConnect;
    FOnClientDisconnect: TOnPipeDisconnect;
    FOnRead: TReadPipeEvent;

    procedure OnPipeConnect(Sender: TObject; Pipe: HPIPE);
    procedure OnPipeDisconnect(Sender: TObject; Pipe: HPIPE);
    procedure OnReadFromPipe(Sender: TObject; Pipe: HPIPE; Stream: TStream);

    function IntWriteMessage(Client: HPIPE; Command: Integer; OutStream: TOutPacketStream): Boolean;
  private
    function GetPipeName: string;
    procedure SetPipeName(const Value: string);
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  public
    constructor Create(const PipeName: string);
    destructor Destroy; override;

    class function Instance: TNamedPipeServer;

    function WriteMessage(Client: HPIPE; Command: Integer; Stream: TStream): Boolean; overload;
    function WriteMessage(Client: HPIPE; Command: Integer; const ABytes: TBytes): Boolean; overload;
    function WriteMessage(Client: HPIPE; Command: Integer; const Msg: string): Boolean; overload;

    function BroadcastMessage(Command: Integer; Stream: TStream): Boolean; overload;
    function BroadcastMessage(Command: Integer; const ABytes: TBytes): Boolean; overload;
    function BroadcastMessage(Command: Integer; const Msg: string): Boolean; overload;

    property PipeName: string read GetPipeName write SetPipeName;
    property Active: Boolean read GetActive write SetActive;
    property Clients: TDictionary<HPIPE, TClientInfo> read FClients;

    property OnClientConnect: TOnPipeConnect read FOnClientConnect write FOnClientConnect;
    property OnClientDisconnect: TOnPipeDisconnect read FOnClientDisconnect write FOnClientDisconnect;
    property OnRead: TReadPipeEvent read FOnRead write FOnRead;
  end;

implementation

uses
  System.StrUtils,
  System.Math;

const
  cDefaultPipeName = 'TestPipe';

  { TNamedPipeClient }

function TNamedPipeClient.Connect: Boolean;
begin
  Result := FPipeClient.Connect(500);
end;

constructor TNamedPipeClient.Create(const ServerName, PipeName: string);
begin
  inherited Create;
  FPipeClient := TPipeClient.Create(nil);
  FPipeClient.OnPipeMessage := OnReadFromPipe;
  SetPipe(ServerName, PipeName);
end;

class constructor TNamedPipeClient.Create;
begin
  FDefaultServerName := '.';
  FDefaultPipeName := cDefaultPipeName;
end;

destructor TNamedPipeClient.Destroy;
begin
  FPipeClient.Disconnect(True);
  FreeAndNil(FPipeClient);
  inherited;
end;

function TNamedPipeClient.GetPipeName: string;
begin
  Result := FPipeClient.PipeName;
end;

function TNamedPipeClient.GetServerName: string;
begin
  Result := FPipeClient.ServerName;
end;

class destructor TNamedPipeClient.Destroy;
begin
  FInstance.Free;
  FInstance := nil;
end;

class procedure TNamedPipeClient.SetDefaultValues(const DefaultServerName, DefaultPipeName: string);
begin
  FDefaultServerName := DefaultServerName;
  FDefaultPipeName := DefaultPipeName;
end;

class function TNamedPipeClient.Instance: TNamedPipeClient;
begin
  if not Assigned(FInstance) then
    FInstance := Self.Create(FDefaultServerName, FDefaultPipeName);
  Result := FInstance;
end;

procedure TNamedPipeClient.OnReadFromPipe(Sender: TObject; Pipe: HPIPE; Stream: TStream);
var
  tmpStream: TInPacketStream;
  PipeBuf: TBytes;
  ReadPos: Integer;
begin
  Stream.Seek(0, soBeginning);
  SetLength(PipeBuf, Stream.Size);
  Stream.Read(PipeBuf, 0, Stream.Size);

  ReadPos := 0;

  while ReadPos < Length(PipeBuf) do
    begin
      if not Assigned(FCurrentData) then
        FCurrentData := TInPacketStream.Create;
      ReadPos := ReadPos + FCurrentData.Write(PipeBuf[ReadPos], Length(PipeBuf) - ReadPos);

      if FCurrentData.Complete then
        begin
          FCurrentData.Seek(0, soBeginning);
          tmpStream := FCurrentData;
          try
            FCurrentData := nil;

            if Assigned(FOnRead) then
              FOnRead(Self, Pipe, tmpStream.PacketHeader.Command, tmpStream);
          finally
            FreeAndNil(tmpStream);
          end;
        end;
    end;
end;

procedure TNamedPipeClient.SetPipe(const ServerName, PipeName: string);
begin
  FPipeClient.Disconnect(True);
  FPipeClient.ServerName := ServerName;
  FPipeClient.PipeName := PipeName;
  Connect;
end;

function TNamedPipeClient.WriteMessage(Command: Integer; Stream: TStream): Boolean;
var
  WriteStream: TOutPacketStream;
begin
  Result := False;

  if not Connect then
    exit;

  WriteStream := TOutPacketStream.Create;
  try
    if Assigned(Stream) then
      WriteStream.CopyFrom(Stream, 0);
    Result := IntWriteMessage(Command, WriteStream);
  finally
    WriteStream.Free;
  end;
end;

function TNamedPipeClient.WriteMessage(Command: Integer; const ABytes: TBytes): Boolean;
var
  WriteStream: TOutPacketStream;
begin
  Result := False;

  if not Connect then
    exit;

  WriteStream := TOutPacketStream.Create;
  try
    if Length(ABytes) <> 0 then
      WriteStream.Write(ABytes, 0, Length(ABytes));
    Result := IntWriteMessage(Command, WriteStream);
  finally
    WriteStream.Free;
  end;
end;

function TNamedPipeClient.WriteMessage(Command: Integer; const Msg: string): Boolean;
begin
  Result := WriteMessage(Command, TEncoding.UTF8.GetBytes(Msg));
end;

function TNamedPipeClient.IntWriteMessage(Command: Integer; OutStream: TOutPacketStream): Boolean;
var
  Bytes: TBytes;
  tmpHeader: TPacketHeader;
begin
  Result := False;

  if not Connect then
    exit;

  tmpHeader := OutStream.PacketHeader;
  tmpHeader.Command := Command;
  OutStream.PacketHeader := tmpHeader;

  OutStream.FillHeader;

  while OutStream.Position < OutStream.Size do
    begin
      SetLength(Bytes, Min(OutStream.Size - OutStream.Position, MAX_BUFFER));
      OutStream.Read(Bytes, 0, Length(Bytes));
      Result := FPipeClient.Write(Bytes[0], Length(Bytes));
      if not Result then
        Break;
    end;
end;

{ TNamedPipeServer }

class destructor TNamedPipeServer.Destroy;
begin
  FInstance.Free;
  FInstance := nil;
end;

destructor TNamedPipeServer.Destroy;
begin
  FServer.Free;
  FServer := nil;

  FServerReadData.Free;
  FServerReadData := nil;

  FClients.Free;
  FClients := nil;
end;

function TNamedPipeServer.GetActive: Boolean;
begin
  Result := FServer.Active;
end;

function TNamedPipeServer.GetPipeName: string;
begin
  Result := FServer.PipeName;
end;

class function TNamedPipeServer.Instance: TNamedPipeServer;
begin
  if not Assigned(FInstance) then
    FInstance := Self.Create(cDefaultPipeName);
  Result := FInstance;
end;

function TNamedPipeServer.IntWriteMessage(Client: HPIPE; Command: Integer; OutStream: TOutPacketStream): Boolean;
var
  Bytes: TBytes;
  tmpHeader: TPacketHeader;
begin
  Result := False;

  tmpHeader := OutStream.PacketHeader;
  tmpHeader.Command := Command;
  OutStream.PacketHeader := tmpHeader;

  OutStream.FillHeader;

  while OutStream.Position < OutStream.Size do
    begin
      SetLength(Bytes, Min(OutStream.Size - OutStream.Position, MAX_BUFFER));
      OutStream.Read(Bytes, 0, Length(Bytes));
      Result := FServer.Write(Client, Bytes[0], Length(Bytes));
      if not Result then
        Break;
    end;
end;

procedure TNamedPipeServer.OnPipeConnect(Sender: TObject; Pipe: HPIPE);
var
  tmpInfo: TClientInfo;
begin
  tmpInfo.Description := '';
  tmpInfo.Data := nil;

  FClients.Add(Pipe, tmpInfo);
  if Assigned(FOnClientConnect) then
    FOnClientConnect(Self, Pipe);
end;

procedure TNamedPipeServer.OnPipeDisconnect(Sender: TObject; Pipe: HPIPE);
begin
  if Assigned(FOnClientDisconnect) then
    FOnClientDisconnect(Self, Pipe);
  FClients.Remove(Pipe);
end;

procedure TNamedPipeServer.OnReadFromPipe(Sender: TObject; Pipe: HPIPE; Stream: TStream);
var
  tmpStream: TInPacketStream;
  CurrentData: TInPacketStream;
  PipeBuf: TBytes;
  ReadPos: Integer;
begin
  Stream.Seek(0, soBeginning);
  SetLength(PipeBuf, Stream.Size);
  Stream.Read(PipeBuf, 0, Stream.Size);

  ReadPos := 0;

  while ReadPos < Length(PipeBuf) do
    begin
      if not FServerReadData.ContainsKey(Pipe) then
        FServerReadData.Add(Pipe, TInPacketStream.Create);
      CurrentData := FServerReadData[Pipe];
      ReadPos := ReadPos + CurrentData.Write(PipeBuf[ReadPos], Length(PipeBuf) - ReadPos);

      if CurrentData.Complete then
        begin
          tmpStream := CurrentData;
          try
            FServerReadData.ExtractPair(Pipe);
            tmpStream.Seek(0, soBeginning);

            if Assigned(FOnRead) then
              FOnRead(Self, Pipe, tmpStream.PacketHeader.Command, tmpStream);
          finally
            FreeAndNil(tmpStream);
          end;
        end;
    end;
end;

procedure TNamedPipeServer.SetActive(const Value: Boolean);
begin
  FServer.Active := Value;
end;

procedure TNamedPipeServer.SetPipeName(const Value: string);
begin
  FServer.PipeName := Value;
end;

function TNamedPipeServer.WriteMessage(Client: HPIPE; Command: Integer; Stream: TStream): Boolean;
var
  WriteStream: TOutPacketStream;
begin
  Result := False;

  if not FClients.ContainsKey(Client) then
    exit;

  WriteStream := TOutPacketStream.Create;
  try
    if Assigned(Stream) then
      WriteStream.CopyFrom(Stream, 0);
    Result := IntWriteMessage(Client, Command, WriteStream);
  finally
    WriteStream.Free;
  end;
end;

function TNamedPipeServer.WriteMessage(Client: HPIPE; Command: Integer; const ABytes: TBytes): Boolean;
var
  WriteStream: TOutPacketStream;
begin
  Result := False;

  if not FClients.ContainsKey(Client) then
    exit;

  WriteStream := TOutPacketStream.Create;
  try
    WriteStream.Write(ABytes, 0, Length(ABytes));
    Result := IntWriteMessage(Client, Command, WriteStream);
  finally
    WriteStream.Free;
  end;
end;

function TNamedPipeServer.WriteMessage(Client: HPIPE; Command: Integer; const Msg: string): Boolean;
begin
  Result := WriteMessage(Client, Command, TEncoding.UTF8.GetBytes(Msg));
end;

function TNamedPipeServer.BroadcastMessage(Command: Integer; Stream: TStream): Boolean;
var
  i: Integer;
begin
  Result := True;

  for i := FServer.ClientCount - 1 downto 0 do
    if not WriteMessage(FServer.Clients[i], Command, Stream) then
      Result := False;
end;

function TNamedPipeServer.BroadcastMessage(Command: Integer; const ABytes: TBytes): Boolean;
var
  i: Integer;
begin
  Result := True;

  for i := FServer.ClientCount - 1 downto 0 do
    if not WriteMessage(FServer.Clients[i], Command, ABytes) then
      Result := False;
end;

function TNamedPipeServer.BroadcastMessage(Command: Integer; const Msg: string): Boolean;
begin
  Result := BroadcastMessage(Command, TEncoding.UTF8.GetBytes(Msg));
end;

constructor TNamedPipeServer.Create(const PipeName: string);
begin
  inherited Create;
  FServerReadData := TObjectDictionary<HPIPE, TInPacketStream>.Create([doOwnsValues]);
  FClients := TDictionary<HPIPE, TClientInfo>.Create;

  FServer := TPipeServer.Create(nil);
  FServer.PipeName := PipeName;
  FServer.OnPipeConnect := OnPipeConnect;
  FServer.OnPipeDisconnect := OnPipeDisconnect;
  FServer.OnPipeMessage := OnReadFromPipe;
end;

end.
