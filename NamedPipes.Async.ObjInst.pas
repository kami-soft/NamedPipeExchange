unit NamedPipes.Async.ObjInst;

interface

// This is unit belongs to Pipes.pas - a component set for Names Pipes
//
// Free Source Code, no license, no guarantee, no liability.
//
// The original author, Russell, gave this to me with no usage restrictions
// whatsoever.
//
// This package prepared by Tobias Giesen, tobias@tgtools.de
//
// March 2004

uses
  Windows,
  SysUtils;

// Declaration of TMessage
type
  TMessage = packed record
    Msg: Cardinal;
    case Integer of
      0:
        (WParam: Longint;
          LParam: Longint;
          Result: Longint);
      1:
        (WParamLo: Word;
          WParamHi: Word;
          LParamLo: Word;
          LParamHi: Word;
          ResultLo: Word;
          ResultHi: Word);
  end;

  // Declaration of TWndMethod
type
  TWndMethod = procedure(var Message: TMessage) of object;

  // Constants for object management
const
  InstanceCount = 313;

  // Object instance record structure
type
  PObjectInstance = ^TObjectInstance;

  TObjectInstance = packed record
    Code: Byte;
    Offset: Integer;
    case Integer of
      0:
        (Next: PObjectInstance);
      1:
        (Method: TWndMethod);
  end;

  // Instance block record structure
type
  PInstanceBlock = ^TInstanceBlock;

  TInstanceBlock = packed record
    Next: PInstanceBlock;
    Counter: Word;
    Code: Array [1 .. 2] of Byte;
    WndProcPtr: Pointer;
    Instances: Array [0 .. InstanceCount] of TObjectInstance;
  end;

function MakeObjectInstance(Method: TWndMethod): Pointer;
procedure FreeObjectInstance(ObjectInstance: Pointer);
function AllocateHWnd(Method: TWndMethod): HWND;
procedure DeallocateHWnd(Wnd: HWND);

implementation

// Global protected variables
var
  InstBlockList: PInstanceBlock = nil;
  InstFreeList: PObjectInstance = nil;
  InstCritSect: TRTLCriticalSection;
  ObjWndClass: TWndClass = (style: 0; lpfnWndProc: @DefWindowProc; cbClsExtra: 0; cbWndExtra: 0; hInstance: 0; hIcon: 0; hCursor: 0; hbrBackground: 0; lpszMenuName: nil;
    lpszClassName: 'ObjWndWindow');

  // Standard window procedure
  // In    ECX = Address of method pointer
  // Out   EAX = Result
function StdWndProc(Window: HWND; Message, WParam: Longint; LParam: Longint): Longint; stdcall; assembler;
asm
  XOR     EAX,EAX
  PUSH    EAX
  PUSH    LParam
  PUSH    WParam
  PUSH    Message
  MOV     EDX,ESP
  MOV     EAX,[ECX].Longint[4]
  CALL    [ECX].Pointer
  ADD     ESP,12
  POP     EAX
end;

function CalcJmpOffset(Src, Dest: Pointer): Longint;
begin
  Result := Longint(Dest) - (Longint(Src) + 5);
end;

function CalcJmpTarget(Src: Pointer; Offs: Integer): Pointer;
begin
  Integer(Result) := Offs + (Longint(Src) + 5);
end;

function GetInstanceBlock(ObjectInstance: Pointer): PInstanceBlock;
var
  oi: PObjectInstance;
begin
  Result := nil;
  oi := ObjectInstance;
  if (oi = nil) then
    exit;
  Pointer(Result) := Pointer(Longint(CalcJmpTarget(oi, oi^.Offset)) - SizeOf(Word) - SizeOf(PInstanceBlock));
end;

function MakeObjectInstance(Method: TWndMethod): Pointer;
const
  BlockCode: Array [1 .. 2] of Byte = ($59, // POP ECX
    $E9); // JMP StdWndProc
  PageSize = 4096;
var
  Block: PInstanceBlock;
  Instance: PObjectInstance;
begin
  EnterCriticalSection(InstCritSect);
  if (InstFreeList = nil) then
    begin
      Block := VirtualAlloc(nil, PageSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Block^.Next := InstBlockList;
      Word(Block^.Code) := Word(BlockCode);
      Block^.WndProcPtr := Pointer(CalcJmpOffset(@Block^.Code[2], @StdWndProc));
      Block^.Counter := 0;
      Instance := @Block^.Instances;
      repeat
        Instance^.Code := $E8; // CALL NEAR PTR Offset
        Instance^.Offset := CalcJmpOffset(Instance, @Block^.Code);
        Instance^.Next := InstFreeList;
        InstFreeList := Instance;
        Inc(Longint(Instance), SizeOf(TObjectInstance));
      until Longint(Instance) - Longint(Block) >= SizeOf(TInstanceBlock);
      InstBlockList := Block;
    end;
  Result := InstFreeList;
  Instance := InstFreeList;
  InstFreeList := Instance^.Next;
  Instance^.Method := Method;
  Inc(GetInstanceBlock(Instance)^.Counter);
  LeaveCriticalSection(InstCritSect);
end;

function FreeInstanceBlock(Block: Pointer): Boolean;
var
  bi: PInstanceBlock;
  oi, poi, noi: PObjectInstance;
begin
  Result := False;
  bi := Block;
  if (bi = nil) or (bi^.Counter <> 0) then
    exit;
  oi := InstFreeList;
  poi := nil;
  while (oi <> nil) do
    begin
      noi := oi^.Next;
      if GetInstanceBlock(oi) = bi then
        begin
          if (poi <> nil) then
            poi^.Next := noi;
          if (oi = InstFreeList) then
            InstFreeList := noi;
        end;
      poi := oi;
      oi := noi;
    end;
  VirtualFree(Block, 0, MEM_RELEASE);
  Result := True;
end;

procedure FreeInstanceBlocks;
var
  pbi, bi, nbi: PInstanceBlock;
begin
  pbi := nil;
  bi := InstBlockList;
  while Assigned(bi) do
    begin
      nbi := bi^.Next;
      if FreeInstanceBlock(bi) then
        begin
          if Assigned(pbi) then
            pbi^.Next := nbi;
          if (bi = InstBlockList) then
            InstBlockList := nbi;
        end;
      pbi := bi;
      bi := nbi;
    end;
end;

procedure FreeObjectInstance(ObjectInstance: Pointer);
var
  bi: PInstanceBlock;
  oi: PObjectInstance;
begin
  oi := ObjectInstance;
  if Assigned(oi) then
    begin
      try
        EnterCriticalSection(InstCritSect);
        bi := GetInstanceBlock(ObjectInstance);
        if Assigned(bi) then
          begin
            if ((bi^.Counter > 0) and (bi^.Counter <= InstanceCount + 1)) then
              begin
                PObjectInstance(ObjectInstance)^.Next := InstFreeList;
                InstFreeList := ObjectInstance;
                Dec(bi^.Counter);
                if (bi^.Counter <= 0) then
                  FreeInstanceBlocks;
              end;
          end;
      finally
        LeaveCriticalSection(InstCritSect);
      end;
    end;
end;

function AllocateHWnd(Method: TWndMethod): HWND;
var
  TempClass: TWndClass;
  ClassReg: Boolean;
begin
  ObjWndClass.hInstance := hInstance;
  ClassReg := GetClassInfo(hInstance, ObjWndClass.lpszClassName, TempClass);
  if not(ClassReg) or (TempClass.lpfnWndProc <> @DefWindowProc) then
    begin
      if ClassReg then
        Windows.UnregisterClass(ObjWndClass.lpszClassName, hInstance);
      Windows.RegisterClass(ObjWndClass);
    end;
  Result := CreateWindowEx(WS_EX_TOOLWINDOW, ObjWndClass.lpszClassName, '', WS_POPUP { !0 } , 0, 0, 0, 0, 0, 0, hInstance, nil);
  if Assigned(Method) then
    SetWindowLong(Result, GWL_WNDPROC, Longint(MakeObjectInstance(Method)));
end;

procedure DeallocateHWnd(Wnd: HWND);
var
  Instance: Pointer;
begin
  Instance := Pointer(GetWindowLong(Wnd, GWL_WNDPROC));
  DestroyWindow(Wnd);
  if (Instance <> @DefWindowProc) then
    FreeObjectInstance(Instance);
end;

initialization

// Multi thread protection
InitializeCriticalSection(InstCritSect);

finalization

// Multi thread protection
DeleteCriticalSection(InstCritSect);

end.
