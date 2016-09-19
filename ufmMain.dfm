object Form12: TForm12
  Left = 0
  Top = 0
  Caption = 'Form12'
  ClientHeight = 242
  ClientWidth = 527
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object btnSendLittleData1: TButton
    Left = 24
    Top = 16
    Width = 113
    Height = 25
    Caption = 'btnSendLittleData1'
    TabOrder = 0
    OnClick = btnSendLittleData1Click
  end
  object btnSendLittleData2: TButton
    Left = 24
    Top = 47
    Width = 113
    Height = 25
    Caption = 'btnSendLittleData2'
    TabOrder = 1
    OnClick = btnSendLittleData2Click
  end
  object btnSendBigData1: TButton
    Left = 24
    Top = 78
    Width = 113
    Height = 25
    Caption = 'btnSendBigData1'
    TabOrder = 2
    OnClick = btnSendBigData1Click
  end
end
