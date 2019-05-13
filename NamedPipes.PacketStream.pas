unit NamedPipes.PacketStream;

interface

uses
  System.SysUtils,
  System.Classes;

type
  TPacketHeader = packed record
    DataSize: integer; // размер заголовка сюда не входит !!!
    Command: Integer;
  end;

  TAbstractOutPacketStream = class(TMemoryStream)
  public
    procedure FillHeader; virtual;
  end;

  TAbstractInPacketStream = class(TMemoryStream)
  protected
    function GetComplete: boolean; virtual; abstract;
  public
    property Complete: boolean read GetComplete;
  end;

  TOutPacketStream = class(TAbstractOutPacketStream)
    // этот поток предназначен для передачи
    // пакета корреспонденту
    // соответственно - при создании ему сообщается
    // заголовок, метод Write записывает данные во "внутренний поток".
    // метод Read выдает данные, считая заголовок их первой частью.
  private
    FPos: Int64;
  strict protected
    FPacketHeader: TPacketHeader;
    FPacketHeaderForSend: TPacketHeader;
  public
    constructor Create;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Read(Buffer: TBytes; Offset, Count: Longint): Longint; override;

    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);

    procedure FillHeader; override;
    procedure Clear;

    property PacketHeader: TPacketHeader read FPacketHeader write FPacketHeader;
  end;

  TInPacketStream = class(TAbstractInPacketStream)
    // здесь наоборот - запись производится начиная с заголовка
    // и сам поток регулирует, сколько данных он "заберет" на основании
    // DataSize
  private
    FPos: Int64;
  strict protected
    FPacketHeader: TPacketHeader;
    FPacketHeaderForReceive: TPacketHeader;
  protected
    function GetComplete: boolean; override;
  public
    constructor Create;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Write(const Buffer: TBytes; Offset, Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);
    procedure Clear;
    property PacketHeader: TPacketHeader read FPacketHeader;
  end;

  TOutPacketStreamClass = class of TAbstractOutPacketStream;
  TInPacketStreamClass = class of TAbstractInPacketStream;

implementation

uses
  WinAPI.Windows,
  System.AnsiStrings;

function MirrorInt(i: integer): integer;
begin
  LongRec(Result).Bytes[0] := LongRec(i).Bytes[3];
  LongRec(Result).Bytes[1] := LongRec(i).Bytes[2];
  LongRec(Result).Bytes[2] := LongRec(i).Bytes[1];
  LongRec(Result).Bytes[3] := LongRec(i).Bytes[0];
end;

{$IFDEF LIMIT_PACKET_SIZE}

const
  MAX_PACKET_SIZE = 65535;
  {$ENDIF}

function Min(const A, B: integer): integer; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

{ TOutPacketStream }

procedure TOutPacketStream.Clear;
begin
  FPacketHeader.DataSize := 0;
  Size := 0;
  FPos := 0;
end;

constructor TOutPacketStream.Create;
begin
  inherited Create;
  FPos := 0;
end;

procedure TOutPacketStream.FillHeader;
begin
  FPacketHeader.DataSize := inherited Seek(0, soEnd);
  FPacketHeaderForSend := FPacketHeader;
  FPacketHeaderForSend.DataSize := MirrorInt(FPacketHeader.DataSize);
  inherited;
end;

procedure TOutPacketStream.LoadFromFile(const FileName: string);
begin
  raise EStreamError.Create('В TOutPacketStream невозможно чтение из файла');
end;

procedure TOutPacketStream.LoadFromStream(Stream: TStream);
begin
  raise EStreamError.Create('В TOutPacketStream невозможно чтение из потока');
end;

function TOutPacketStream.Read(Buffer: TBytes; Offset, Count: Longint): Longint;
begin
  Result:=Read(Buffer[Offset], Count);
end;

function TOutPacketStream.Read(var Buffer; Count: integer): Longint;
var
  Pb: PAnsiChar;
begin
  Result := 0;
  if Count > 0 then
    begin
      Pb := @Buffer;
      if FPos < sizeof(TPacketHeader) then
        begin
          Result := Min(Count, sizeof(TPacketHeader) - FPos);
          // Move(PAnsiChar(@FPacketHeader)[FPos], Pb^, Result);
          CopyMemory(Pb, @PAnsiChar(@FPacketHeaderForSend)[FPos], Result);
          Dec(Count, Result);
        end;
      if Count > 0 then
        Result := Result + inherited read(Pb[Result], Count);
      Inc(FPos, Result);
    end;
end;

function TOutPacketStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPos := Offset;
    soCurrent:
      Inc(FPos, Offset);
    soEnd:
      FPos := Int64(sizeof(TPacketHeader)) + inherited Seek(0, soEnd) - Offset;
  end;
  if FPos < 0 then
    FPos := 0;
  Result := FPos;
  if Result >= sizeof(TPacketHeader) then
    inherited Seek(Result - sizeof(TPacketHeader), soBeginning)
  else
    inherited Seek(0, soBeginning);
end;

{ TInPacketStream }

procedure TInPacketStream.Clear;
begin
  Size := 0;
  FPos := 0;
end;

constructor TInPacketStream.Create;
begin
  inherited Create;
  FPos := 0;
  FPacketHeader.DataSize := 0;
end;

function TInPacketStream.GetComplete: boolean;
begin
  Result := FPos = sizeof(TPacketHeader) + FPacketHeader.DataSize;
  if FPos > (sizeof(TPacketHeader) + FPacketHeader.DataSize) then
    raise EInOutError.Create('Ошибка при приеме пакета в сокете');
end;

procedure TInPacketStream.LoadFromFile(const FileName: string);
begin
  raise EStreamError.Create('В TInPacketStream невозможно чтение из файла');
end;

procedure TInPacketStream.LoadFromStream(Stream: TStream);
begin
  raise EStreamError.Create('В TInPacketStream невозможно чтение из потока');
end;

function TInPacketStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := 0;
  if not Complete then
    EStreamError.Create('Невозможно изменение позиции до полного приема пакета')
  else
    Result := inherited Seek(Offset, Origin);
end;

function TInPacketStream.Write(const Buffer: TBytes; Offset, Count: Longint): Longint;
begin
  Result:=Write(Buffer[Offset], Count);
end;

function TInPacketStream.Write(const Buffer; Count: integer): Longint;
var
  Pb: PAnsiChar;
begin
  Result := 0;
  if (Count <= 0) then
    raise EInOutError.Create('Ошибка TInPacketStream - неверная попытка записи. Невозможно записать count=' + IntToStr(Count));
  if Complete then
    begin
      raise EInOutError.Create('Ошибка TInPacketStream - неверная попытка записи. поток закрыт. FDataSize=' + IntToStr(FPacketHeader.DataSize) + ' FPos = ' + IntToStr(FPos) +
        ' HeaderSize = ' + IntToStr(sizeof(TPacketHeader)) + '  пытаемся записать ' + IntToStr(Count));
    end;
  Pb := @Buffer;
  if FPos < sizeof(TPacketHeader) then
    begin
      Result := Min(Count, sizeof(TPacketHeader) - FPos);
      // Move(Pb^, PAnsiChar(@FPacketHeader)[FPos], Result);
      CopyMemory(@PAnsiChar(@FPacketHeaderForReceive)[FPos], Pb, Result);
      Dec(Count, Result);
      Inc(FPos, Result);
      if FPos = sizeof(TPacketHeader) then
        begin
          FPacketHeader := FPacketHeaderForReceive;
          FPacketHeader.DataSize := MirrorInt(FPacketHeader.DataSize);
        end;
    end;
  if Count > 0 then
    begin
      {$IFDEF LIMIT_PACKET_SIZE}
      if FPacketHeader.DataSize > MAX_PACKET_SIZE then
        raise EInOutError.Create('Размер пакета превышает допустимый');
      {$ENDIF}
      if not Complete then
        begin
          Count := Min(Count, FPacketHeader.DataSize - (FPos - sizeof(TPacketHeader)));
          Result := Result + inherited write(Pb[Result], Count);
          Inc(FPos, Count);
        end;
    end;
end;

{ TAbstractOutPacketStream }

procedure TAbstractOutPacketStream.FillHeader;
begin
  Seek(0, soBeginning);
end;

end.
