program ProjectNamedPipesExchangeTests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  DUnitTestRunner,
  TestuNamedPipesExchange in 'TestuNamedPipesExchange.pas',
  uNamedPipesExchange in '..\uNamedPipesExchange.pas',
  TestNamedPipes in 'TestNamedPipes.pas',
  NamedPipes.Async in '..\NamedPipes.Async.pas';

{ R *.RES }

begin
  DUnitTestRunner.RunRegisteredTests;

end.
