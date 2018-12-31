/// /////////////////////////////////////////////////////////////////////////////
//
// ****************************************************************************
// * Unit Name : FWIOCompletionPipes
// * Purpose   : Реализация сервера на основе именованных каналов
// *           : с использованием IoCompletion, а так-же клиентской части
// * Author    : Александр (Rouse_) Багель
// * Copyright : © Fangorn Wizards Lab 1998 - 2012.
// * Version   : 1.01
// * Home Page : http://rouse.drkb.ru
// ****************************************************************************
//

unit FWIOCompletionPipes;

interface

{$WARN SYMBOL_PLATFORM OFF}

uses
  Windows,
  SysUtils,
  Classes;

const
  MaxBuffSize = MAXWORD;

type
  PFWPipeData = ^TFWPipeData;

  EPipeServerException = class(Exception)
  end;

  TConnectEvent = procedure(Sender: TObject; PipeHandle: PFWPipeData) of object;
  TOnReadEvent = procedure(Sender: TObject; PipeInstance: PFWPipeData) of object;

  TFWPipeServer = class
  private
    FActive: Boolean;
    FEvent: THandle;
    FPipeName: string;
    FConnect: TConnectEvent;
    FPipeInstances: TList;
    FDisconnect: TConnectEvent;
    FRead: TOnReadEvent;
    FIdle: TNotifyEvent;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  protected
    procedure DoConnect(PipeHandle: THandle);
    procedure DoDisconnect(Value: PFWPipeData);
    procedure DoIdle;
    procedure DoRead(Value: PFWPipeData);
  protected
    function CreatePipeInstance(out NewPipeHandle: THandle; Value: TOverlapped): Boolean;
    procedure DoWork;
  public
    constructor Create(const PipeName: string); virtual;
    destructor Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    property OnConnect: TConnectEvent read FConnect write FConnect;
    property OnDisconnect: TConnectEvent read FDisconnect write FDisconnect;
    property OnNeedProcessReadAndWrite: TOnReadEvent read FRead write FRead;
    property OnIdle: TNotifyEvent read FIdle write FIdle;
  end;

  TFWPipeData = record
    Overlaped: TOverlapped;
    PipeHandle: THandle;
    ServerInstance: TFWPipeServer;
    ReadBuff: array [0 .. MaxBuffSize - 1] of Byte;
    ReadBuffSize: Cardinal;
    WriteBuff: array [0 .. MaxBuffSize - 1] of Byte;
    WriteBuffSize: Cardinal;
    UserData: Pointer;
  end;

  TOnClientReadEvent = procedure(Sender: TObject; pData: Pointer; cbSize: Cardinal) of object;

  TFWPipeClient = class
  private
    FEvent: THandle;
    FPipe: THandle;
    FPipeName: string;
    // FRead: TOnClientReadEvent;
    FConnect: TNotifyEvent;
    FDisconnect: TNotifyEvent;
    FBuff: array [0 .. MaxBuffSize - 1] of Byte;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  public
    constructor Create(const ServerName, PipeName: string); virtual;
    destructor Destroy; override;
    procedure SendData(var pData: Pointer; var cbSize: Cardinal); overload;
    procedure SendData(InStream, OutStream: TStream); overload;
    property Active: Boolean read GetActive write SetActive;
    property OnConnect: TNotifyEvent read FConnect write FConnect;
    property OnDisconnect: TNotifyEvent read FDisconnect write FDisconnect;
    // property OnRead: TOnClientReadEvent read FRead write FRead;
  end;

procedure CompletedReadRoutine(dwErr, cbBytesRead: DWORD; lpOverLap: POverlapped); stdcall;

implementation

const
  STATE_RELEASED = 0;
  STATE_WAIT_CONNECT = 1;
  STATE_READING = 2;
  STATE_WRITING = 3;

  { TFWPipeServerThread }

procedure CompletedWriteRoutine(dwErr, cbWritten: DWORD; lpOverLap: POverlapped); stdcall;
var
  PipeInstance: PFWPipeData;
  AResult: Boolean;
begin
  AResult := False;
  PipeInstance := PFWPipeData(lpOverLap);
  if (dwErr = 0) and (cbWritten = PipeInstance^.WriteBuffSize) then
    AResult := ReadFileEx(PipeInstance^.PipeHandle, @PipeInstance^.ReadBuff[0], MaxBuffSize, lpOverLap, @CompletedReadRoutine);
  if not AResult then
    PipeInstance^.ServerInstance.DoDisconnect(PipeInstance);
end;

procedure CompletedReadRoutine(dwErr, cbBytesRead: DWORD; lpOverLap: POverlapped); stdcall;
var
  PipeInstance: PFWPipeData;
  AResult: Boolean;
begin
  AResult := False;
  PipeInstance := PFWPipeData(lpOverLap);
  if (dwErr = 0) and (cbBytesRead <> 0) then
    begin
      PipeInstance^.ReadBuffSize := cbBytesRead;
      PipeInstance^.ServerInstance.DoRead(PipeInstance);
      AResult := WriteFileEx(PipeInstance^.PipeHandle, @PipeInstance^.WriteBuff[0], PipeInstance^.WriteBuffSize, lpOverLap^, @CompletedWriteRoutine);
    end;
  if not AResult then
    PipeInstance^.ServerInstance.DoDisconnect(PipeInstance);
end;

{ TFWPipeServer }

type
  PACE_HEADER = ^ACE_HEADER;
  {$EXTERNALSYM PACE_HEADER}

  _ACE_HEADER = record
    AceType: Byte;
    AceFlags: Byte;
    AceSize: Word;
  end;
  {$EXTERNALSYM _ACE_HEADER}

  ACE_HEADER = _ACE_HEADER;
  {$EXTERNALSYM ACE_HEADER}
  TAceHeader = ACE_HEADER;
  PAceHeader = PACE_HEADER;

  PACCESS_ALLOWED_ACE = ^ACCESS_ALLOWED_ACE;
  {$EXTERNALSYM PACCESS_ALLOWED_ACE}

  _ACCESS_ALLOWED_ACE = record
    Header: ACE_HEADER;
    Mask: ACCESS_MASK;
    SidStart: DWORD;
  end;
  {$EXTERNALSYM _ACCESS_ALLOWED_ACE}

  ACCESS_ALLOWED_ACE = _ACCESS_ALLOWED_ACE;
  {$EXTERNALSYM ACCESS_ALLOWED_ACE}
  TAccessAllowedAce = ACCESS_ALLOWED_ACE;
  PAccessAllowedAce = PACCESS_ALLOWED_ACE;

constructor TFWPipeServer.Create(const PipeName: string);
begin
  FPipeName := PipeName;
  FPipeInstances := TList.Create;
end;

function TFWPipeServer.CreatePipeInstance(out NewPipeHandle: THandle; Value: TOverlapped): Boolean;
const
  SECURITY_WORLD_SID_AUTHORITY: TSidIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 1));
  SECURITY_WORLD_RID = ($00000000);
  ACL_REVISION = (2);
var
  SIA: SID_IDENTIFIER_AUTHORITY;
  SID: PSID;
  DaclSize: Integer;
  ACL: PACL;
  Descriptor: SECURITY_DESCRIPTOR;
  Attributes: SECURITY_ATTRIBUTES;
begin
  Result := False;
  try
    SIA := SECURITY_WORLD_SID_AUTHORITY;
    SID := AllocMem(GetSidLengthRequired(1));
    try
      Win32Check(InitializeSid(SID, SECURITY_WORLD_SID_AUTHORITY, 1));
      PDWORD(GetSidSubAuthority(SID, 0))^ := SECURITY_WORLD_RID;
      DaclSize := SizeOf(ACL) + SizeOf(ACCESS_ALLOWED_ACE) + GetLengthSid(SID);
      ACL := AllocMem(DaclSize);
      try
        Win32Check(InitializeAcl(ACL^, DaclSize, ACL_REVISION));
        Win32Check(AddAccessAllowedAce(ACL^, ACL_REVISION, GENERIC_ALL, SID));
        Win32Check(InitializeSecurityDescriptor(@Descriptor, SECURITY_DESCRIPTOR_REVISION));
        Win32Check(SetSecurityDescriptorDacl(@Descriptor, True, ACL, False));
        Attributes.nLength := SizeOf(SECURITY_ATTRIBUTES);
        Attributes.lpSecurityDescriptor := @Descriptor;
        Attributes.bInheritHandle := False;

        NewPipeHandle := CreateNamedPipe(PChar('\\.\pipe\' + FPipeName), PIPE_ACCESS_DUPLEX or FILE_FLAG_OVERLAPPED, PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
          PIPE_UNLIMITED_INSTANCES, MaxBuffSize, MaxBuffSize, NMPWAIT_WAIT_FOREVER, @Attributes);

        if NewPipeHandle = INVALID_HANDLE_VALUE then
          RaiseLastOSError
        else
          begin
            if not ConnectNamedPipe(NewPipeHandle, @Value) then
              begin
                case GetLastError of
                  ERROR_IO_PENDING:
                    Result := True;
                  ERROR_PIPE_CONNECTED:
                    SetEvent(Value.hEvent);
                else
                  RaiseLastOSError;
                end;
              end
            else
              DoConnect(NewPipeHandle);
          end;
      finally
        FreeMem(ACL);
      end;
    finally
      FreeMem(SID);
    end;
  except
    if NewPipeHandle <> INVALID_HANDLE_VALUE then
      begin
        CloseHandle(NewPipeHandle);
        NewPipeHandle := INVALID_HANDLE_VALUE;
      end;
    raise;
  end;
end;

destructor TFWPipeServer.Destroy;
begin
  Active := False;
  FPipeInstances.Free;
  inherited;
end;

procedure TFWPipeServer.DoConnect(PipeHandle: THandle);
var
  PipeInstance: PFWPipeData;
begin
  PipeInstance := PFWPipeData(GlobalAlloc(GPTR, SizeOf(TFWPipeData)));
  FPipeInstances.Add(PipeInstance);
  PipeInstance^.PipeHandle := PipeHandle;
  PipeInstance^.ServerInstance := Self;
  PipeInstance^.WriteBuffSize := 0;
  if Assigned(FConnect) then
    FConnect(Self, PipeInstance);
  if PipeInstance^.ServerInstance <> nil then
    CompletedWriteRoutine(0, 0, POverlapped(PipeInstance));
end;

procedure TFWPipeServer.DoDisconnect(Value: PFWPipeData);
var
  Index: Integer;
begin
  Index := FPipeInstances.IndexOf(Value);
  if Index >= 0 then
    FPipeInstances.Delete(Index);
  DisconnectNamedPipe(Value.PipeHandle);
  CloseHandle(Value.PipeHandle);
  if Assigned(FDisconnect) then
    FDisconnect(Self, Value);
  GlobalFree(NativeUInt(Value));
end;

procedure TFWPipeServer.DoIdle;
begin
  if Assigned(FIdle) then
    FIdle(Self);
end;

procedure TFWPipeServer.DoRead(Value: PFWPipeData);
begin
  if Assigned(FRead) then
    FRead(Self, Value);
end;

procedure TFWPipeServer.DoWork;
var
  Index: Cardinal;
  lpNumberOfBytesTransferred: Cardinal;
  PendingIO: Boolean;
  ConnectOverlapped: TOverlapped;
  NewPipeHandle: THandle;
begin
  ZeroMemory(@ConnectOverlapped, SizeOf(TOverlapped));
  ConnectOverlapped.hEvent := FEvent;
  PendingIO := CreatePipeInstance(NewPipeHandle, ConnectOverlapped);
  try
    while FActive do
      begin
        Index := WaitForSingleObjectEx(FEvent, 100, True);
        case Index of
          WAIT_FAILED:
            RaiseLastOSError;
          WAIT_TIMEOUT:
            begin
              DoIdle;
              Continue;
            end;
          WAIT_IO_COMPLETION:
            Continue;
          WAIT_OBJECT_0:
            begin
              if PendingIO then
                begin
                  if not GetOverlappedResult(NewPipeHandle, ConnectOverlapped, lpNumberOfBytesTransferred, False) then
                    RaiseLastOSError
                  else
                    DoConnect(NewPipeHandle);
                end;
              PendingIO := CreatePipeInstance(NewPipeHandle, ConnectOverlapped);
            end;
        end;
      end;
  finally
    CloseHandle(NewPipeHandle);
  end;
end;

function TFWPipeServer.GetActive: Boolean;
begin
  Result := FActive and (FEvent <> 0);
end;

procedure TFWPipeServer.SetActive(const Value: Boolean);
var
  I: Integer;
begin
  if Value then
    begin
      if not Active then
        begin
          FEvent := CreateEvent(nil, True, True, nil);
          if FEvent = 0 then
            RaiseLastOSError;
          FActive := True;
          DoWork;
        end;
    end
  else
    begin
      if FEvent <> 0 then
        begin
          CloseHandle(FEvent);
          FEvent := 0;
        end;
      for I := FPipeInstances.Count - 1 downto 0 do
        DoDisconnect(FPipeInstances[I]);
      FActive := False;
    end;
end;

{ TFWPipeClient }

constructor TFWPipeClient.Create(const ServerName, PipeName: string);
begin
  FPipeName := '\\' + ServerName + '\pipe\' + PipeName;
  FEvent := 0;
  FPipe := INVALID_HANDLE_VALUE;
end;

destructor TFWPipeClient.Destroy;
begin
  Active := False;
  inherited;
end;

function TFWPipeClient.GetActive: Boolean;
begin
  Result := (FEvent <> 0) and (FPipe <> INVALID_HANDLE_VALUE);
end;

procedure TFWPipeClient.SendData(var pData: Pointer; var cbSize: Cardinal);
begin
  Win32Check(TransactNamedPipe(FPipe, pData, cbSize, @FBuff[0], MaxBuffSize, cbSize, nil));
  pData := @FBuff[0];
end;

procedure TFWPipeClient.SendData(InStream, OutStream: TStream);
var
  lpBytesRead: Cardinal;
begin
  InStream.Position := 0;
  InStream.ReadBuffer(FBuff[0], InStream.Size);
  Win32Check(TransactNamedPipe(FPipe, @FBuff[0], InStream.Size, @FBuff[0], MaxBuffSize, lpBytesRead, nil));
  OutStream.Size := 0;
  OutStream.WriteBuffer(FBuff[0], lpBytesRead);
  OutStream.Position := 0;
end;

procedure TFWPipeClient.SetActive(const Value: Boolean);
var
  LastError, lpMode: Cardinal;
  AllowDisconnectEvent: Boolean;
begin
  if Value then
    begin
      if Active then
        Exit;
      FEvent := CreateEvent(nil, True, True, nil);
      if FEvent = 0 then
        RaiseLastOSError;
      FPipe := CreateFile(PChar(FPipeName), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
      if FPipe = INVALID_HANDLE_VALUE then
        begin
          CloseHandle(FEvent);
          FEvent := 0;
          RaiseLastOSError;
        end;
      case GetLastError of
        NOERROR, ERROR_PIPE_BUSY:
          ;
      else
        LastError := GetLastError;
        Active := False;
        SetLastError(LastError);
        RaiseLastOSError;
      end;
      if not WaitNamedPipe(PChar(FPipeName), 10000 { NMPWAIT_WAIT_FOREVER } ) then
        begin
          LastError := GetLastError;
          Active := False;
          SetLastError(LastError);
          RaiseLastOSError;
        end;
      lpMode := PIPE_READMODE_MESSAGE;
      Win32Check(SetNamedPipeHandleState(FPipe, lpMode, nil, nil));
      if Assigned(FConnect) then
        FConnect(Self);
    end
  else
    begin
      AllowDisconnectEvent := False;
      if FEvent <> 0 then
        begin
          CloseHandle(FEvent);
          FEvent := 0;
          AllowDisconnectEvent := True;
        end;
      if FPipe <> INVALID_HANDLE_VALUE then
        begin
          CloseHandle(FPipe);
          FPipe := INVALID_HANDLE_VALUE;
          AllowDisconnectEvent := True;
        end;
      if Assigned(FDisconnect) and AllowDisconnectEvent then
        FDisconnect(Self);
    end;
end;

end.
