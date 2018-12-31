////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Unit Name : server
//  * Purpose   : Демонстрационный пример работы сервера
//  * Author    : Александр (Rouse_) Багель
//  * Copyright : © Fangorn Wizards Lab 1998 - 2012.
//  * Version   : 1.01
//  * Home Page : http://rouse.drkb.ru
//  ****************************************************************************
//

// Показан примерный принцип работы с классом TFWPipeServer
// Задача демосервера получить от клиента некую строку,
// добавить к ней константу "DONE" и отправить результат клиенту.
// При получении от клиента числа -1 сервер должен завершить свою работу.

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

//  Инициализация сервера
// =============================================================================
constructor TSimpleObject.Create;
begin
  // Флаг NeedStop используется для остановки сервера
  NeedStop := False;
  // Создаем сервер
  FServer := TFWPipeServer.Create('FWIOCompletionPipeServer');
  // Назначаем обработчики
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

//  Метод вызывается при подсоединении нового клиента
// =============================================================================
procedure TSimpleObject.Connect(Sender: TObject; PipeHandle: PFWPipeData);
begin
  Writeln('New client connected. Handle ', PipeHandle^.PipeHandle);
end;

//  Метод вызывается при отсоединении клиента
// =============================================================================
procedure TSimpleObject.Disconnect(Sender: TObject; PipeHandle: PFWPipeData);
begin
  Writeln('Client with handle ', PipeHandle^.PipeHandle, ' disconnected');
end;

//  Метод вызывается в тот момент когда сервер ничем не занят
// =============================================================================
procedure TSimpleObject.Idle(Sender: TObject);
begin
  if NeedStop then
    FServer.Active := False;
end;

//  Метод вызывается при получении данных от клиента
// =============================================================================
procedure TSimpleObject.Read(Sender: TObject; PipeInstance: PFWPipeData);
var
  Len: Integer;
  Buff: AnsiString;
begin
  // Проверяем размер приемного буффера.
  // В данном демо режиме клиент всегда должен
  // отправлять данные размером не менее 4 байт
  if PipeInstance^.ReadBuffSize < 4 then
    raise Exception.Create('Wrong readbuff size.');

  // Читаем размер данных
  Move(PipeInstance^.ReadBuff[0], Len, 4);


  // Проверка, получено ли число -1?
  if Len = -1  then
    // Если получено - то выставляем флаг о необходимости остановки сервера
    // Данный флаг будет зачитан в режиме IDLE и сервер будет корректно остановлен
    // Если останавливать сервер прямо сейчас командой FServer.Active := False,
    // то клиент получит ошибку о том что на другой стороне пайпа никого нет.
    NeedStop := True
  else
  begin
    // Если получено число отличное от -1, зачитываем буфер с текстом
    // добавляем к нему слово "DONE" и отправляем обратно
    if Len > 0 then
    begin
      SetLength(Buff, Len);
      Move(PipeInstance^.ReadBuff[4], Buff[1], Len);
      Buff := Buff + 'DONE';
      Len := Length(Buff);
      Move(Len, PipeInstance^.WriteBuff[0], 4);
      Move(Buff[1], PipeInstance^.WriteBuff[4], Len);
      // При этом не забываем указать размер отправляемого буффера
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
      // тонкий момент, после команды Server.Active := True управление на
      // следующую строку кода не произойдет до тех пор, пока сервер
      // не будет остановлен, т.е. не будет выполнена команда
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
