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

// ������� ��������� ������� ������ � ������� TFWPipeClient
// ������ ����������� ��������� ������� ����� ������, �������� ��������� � ���������,
// ��������� �� �� ������������ ������ � ���������� ���������� "DONE".
// ������� �� ����� ��������� ��������.
// ����� ���������� �������� ���� ����, ��������� ������� ����� -1,
// ��� ��������� �������� ������ ������ ��������� ���� ������.


program client;

{$APPTYPE CONSOLE}

uses
  Windows,
  FWIOCompletionPipes,
  Classes,
  SysUtils;

function ToOEM(str: string): AnsiString;
begin
  SetLength(Result, Length(str));
  AnsiToOem(@AnsiString(str)[1], @Result[1]);
end;

var
  I, Len: Integer;
  InData, OutData: AnsiString;
  PipeClient: TFWPipeClient;
  InStream, OutStream: TMemoryStream;
begin
  try
    PipeClient := TFWPipeClient.Create('.', 'FWIOCompletionPipeServer');
    try
      PipeClient.Active := True;
      InStream := TMemoryStream.Create;
      try
        OutStream := TMemoryStream.Create;
        try
          for I := 0 to 10000 do
          begin
            InData := 'Value: ' + AnsiString(IntToStr(I));
            Len := Length(InData);
            InStream.Clear;
            InStream.WriteBuffer(Len, 4);
            InStream.WriteBuffer(InData[1], Len);
            PipeClient.SendData(InStream, OutStream);
            OutStream.ReadBuffer(Len, 4);
            if Len <= 0 then
              raise Exception.Create('Wrong buff');
            SetLength(OutData, Len);
            OutStream.ReadBuffer(OutData[1], Len);
            InData := InData + 'DONE';
            if InData = OutData then
              Writeln('Send data success ', InData)
            else
              Writeln('Send data failed ', InData, ' <> ', OutData);
            //Sleep(50);
          end;
          InStream.Clear;
          I := -1;
          InStream.WriteBuffer(I, 4);
          PipeClient.SendData(InStream, OutStream);
        finally
          OutStream.Free;
        end;
      finally
        InStream.Free;
      end;
    finally
      PipeClient.Free;
    end;
  except
    on E:Exception do
      Writeln(ToOem(E.Classname+': '+ E.Message));
  end;
  Readln;
end.
