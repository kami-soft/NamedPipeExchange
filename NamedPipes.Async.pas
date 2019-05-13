unit NamedPipes.Async;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  NamedPipes.PacketStream,
  NamedPipes.Async.Classes;

type
  TReadPipeEvent = procedure(Sender: TObject; Command: Integer; Data: TStream) of object;

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
  public
    constructor Create(const ServerName, PipeName: string);
    destructor Destroy; override;

    procedure SetPipe(const ServerName, PipeName: string);

    function Connect: Boolean;
    function WriteMessage(Stream: TStream): Boolean; overload;
    function WriteMessage(const ABytes: TBytes): Boolean; overload;
    function WriteMessage(const Msg: string): Boolean; overload;

    class procedure Init(const DefaultServerName, DefaultPipeName: string);
    class function Instance: TNamedPipeClient;

    property ServerName: string read GetServerName;
    property PipeName: string read GetPipeName;
    property OnRead: TReadPipeEvent read FOnRead write FOnRead;
  end;

implementation

uses
  System.StrUtils;

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
  FInstance := nil;
end;

class procedure TNamedPipeClient.Init(const DefaultServerName, DefaultPipeName: string);
begin
  FDefaultServerName := DefaultServerName;
  FDefaultPipeName := DefaultPipeName;
end;

class function TNamedPipeClient.Instance: TNamedPipeClient;
begin
  if not Assigned(FInstance) then
    FInstance := TNamedPipeClient.Create(FDefaultServerName, FDefaultPipeName);
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
              FOnRead(Self, tmpStream.PacketHeader.Command, tmpStream);
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

function TNamedPipeClient.WriteMessage(Stream: TStream): Boolean;
var
  WriteStream: TOutPacketStream;
  Bytes: TBytes;
begin
  Result := False;

  if not Connect then
    exit;

  if Stream.Size = 0 then
    exit;

  WriteStream := TOutPacketStream.Create;
  try
    WriteStream.CopyFrom(Stream, 0);
    WriteStream.FillHeader;

    SetLength(Bytes, WriteStream.Size);
    WriteStream.Read(Bytes, 0, WriteStream.Size);
    Result := FPipeClient.Write(Bytes[0], Length(Bytes));
  finally
    WriteStream.Free;
  end;
end;

function TNamedPipeClient.WriteMessage(const ABytes: TBytes): Boolean;
var
  WriteStream: TOutPacketStream;
  Bytes: TBytes;
begin
  Result := False;

  if not Connect then
    exit;

  if Length(ABytes) = 0 then
    exit;

  WriteStream := TOutPacketStream.Create;
  try
    WriteStream.Write(ABytes, 0, Length(ABytes));
    WriteStream.FillHeader;

    SetLength(Bytes, WriteStream.Size);
    WriteStream.Read(Bytes, 0, WriteStream.Size);
    Result := FPipeClient.Write(Bytes[0], Length(Bytes));
  finally
    WriteStream.Free;
  end;
end;

function TNamedPipeClient.WriteMessage(const Msg: string): Boolean;
begin
  Result := WriteMessage(TEncoding.UTF8.GetBytes(Msg));
end;

end.
