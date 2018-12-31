////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Unit Name : server
//  * Purpose   : ���������������� ������ ������ �������
//  * Author    : ��������� (Rouse_) ������
//  * Copyright : � Fangorn Wizards Lab 1998 - 2012.
//  * Version   : 1.01
//  * Home Page : http://rouse.drkb.ru
//  ****************************************************************************
//

// ������� ��������� ������� ������ � ������� TFWPipeServer
// ������ ����������� �������� �� ������� ����� ������,
// �������� � ��� ��������� "DONE" � ��������� ��������� �������.
// ��� ��������� �� ������� ����� -1 ������ ������ ��������� ���� ������.

program server;

{$APPTYPE CONSOLE}

uses
  Windows,
  FWIOCompletionPipes,
  SysUtils;

type
  TSimpleObject = class
  private
    FServer: TFWPipeServer;
    NeedStop: Boolean;
  protected
    procedure Connect(Sender: TObject; PipeHandle: PFWPipeData);
    procedure Disconnect(Sender: TObject; PipeHandle: PFWPipeData);
    procedure Read(Sender: TObject; PipeInstance: PFWPipeData);
    procedure Idle(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    property Server: TFWPipeServer read FServer;
  end;

{ TSimpleObject }

//  ������������� �������
// =============================================================================
constructor TSimpleObject.Create;
begin
  // ���� NeedStop ������������ ��� ��������� �������
  NeedStop := False;
  // ������� ������
  FServer := TFWPipeServer.Create('FWIOCompletionPipeServer');
  // ��������� �����������
  FServer.OnConnect := Connect;
  FServer.OnDisconnect := Disconnect;
  FServer.OnNeedProcessReadAndWrite := Read;
  FServer.OnIdle := Idle;
end;

destructor TSimpleObject.Destroy;
begin
  FServer.Free;
  inherited;
end;

//  ����� ���������� ��� ������������� ������ �������
// =============================================================================
procedure TSimpleObject.Connect(Sender: TObject; PipeHandle: PFWPipeData);
begin
  Writeln('New client connected. Handle ', PipeHandle^.PipeHandle);
end;

//  ����� ���������� ��� ������������ �������
// =============================================================================
procedure TSimpleObject.Disconnect(Sender: TObject; PipeHandle: PFWPipeData);
begin
  Writeln('Client with handle ', PipeHandle^.PipeHandle, ' disconnected');
end;

//  ����� ���������� � ��� ������ ����� ������ ����� �� �����
// =============================================================================
procedure TSimpleObject.Idle(Sender: TObject);
begin
  if NeedStop then
    FServer.Active := False;
end;

//  ����� ���������� ��� ��������� ������ �� �������
// =============================================================================
procedure TSimpleObject.Read(Sender: TObject; PipeInstance: PFWPipeData);
var
  Len: Integer;
  Buff: AnsiString;
begin
  // ��������� ������ ��������� �������.
  // � ������ ���� ������ ������ ������ ������
  // ���������� ������ �������� �� ����� 4 ����
  if PipeInstance^.ReadBuffSize < 4 then
    raise Exception.Create('Wrong readbuff size.');

  // ������ ������ ������
  Move(PipeInstance^.ReadBuff[0], Len, 4);


  // ��������, �������� �� ����� -1?
  if Len = -1  then
    // ���� �������� - �� ���������� ���� � ������������� ��������� �������
    // ������ ���� ����� ������� � ������ IDLE � ������ ����� ��������� ����������
    // ���� ������������� ������ ����� ������ �������� FServer.Active := False,
    // �� ������ ������� ������ � ��� ��� �� ������ ������� ����� ������ ���.
    NeedStop := True
  else
  begin
    // ���� �������� ����� �������� �� -1, ���������� ����� � �������
    // ��������� � ���� ����� "DONE" � ���������� �������
    if Len > 0 then
    begin
      SetLength(Buff, Len);
      Move(PipeInstance^.ReadBuff[4], Buff[1], Len);
      Buff := Buff + 'DONE';
      Len := Length(Buff);
      Move(Len, PipeInstance^.WriteBuff[0], 4);
      Move(Buff[1], PipeInstance^.WriteBuff[4], Len);
      // ��� ���� �� �������� ������� ������ ������������� �������
      PipeInstance^.WriteBuffSize := Len + 4;
    end;
  end;
end;


function ToOEM(str: string): AnsiString;
begin
  SetLength(Result, Length(str));
  AnsiToOem(@AnsiString(str)[1], @Result[1]);
end;

var
  SimpleObj: TSimpleObject;
begin
  try
    SimpleObj := TSimpleObject.Create;
    try
      // ������ ������, ����� ������� Server.Active := True ���������� ��
      // ��������� ������ ���� �� ���������� �� ��� ���, ���� ������
      // �� ����� ����������, �.�. �� ����� ��������� �������
      // Server.Active := False
      SimpleObj.Server.Active := True;
      Writeln('Server stopped');
    finally
      SimpleObj.Free;
    end;
  except
    on E:Exception do
      Writeln(ToOEM(E.Classname+': '+ E.Message));
  end;
  Readln;
end.
