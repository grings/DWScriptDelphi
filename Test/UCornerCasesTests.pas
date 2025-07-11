unit UCornerCasesTests;

interface

uses
   Windows, Classes, SysUtils,
   dwsXPlatformTests, dwsComp, dwsCompiler, dwsExprs, dwsDataContext, dwsInfo,
   dwsTokenTypes, dwsXPlatform, dwsFileSystem, dwsErrors, dwsUtils, Variants,
   dwsSymbols, dwsPascalTokenizer, dwsStrings, dwsJSON, dwsFunctions,
   dwsFilter, dwsScriptSource, dwsSymbolDictionary, dwsContextMap,
   dwsCompilerContext, dwsUnitSymbols;

type

   TCornerCasesTests = class (TTestCase)
      private
         FCompiler : TDelphiWebScript;
         FUnit : TdwsUnit;
         FLastResource : String;

      public
         procedure SetUp; override;
         procedure TearDown; override;
         procedure DoOnInclude(const scriptName : String; var scriptSource : String);
         function  DoOnNeedUnit(const unitName : String; var unitSource, unitLocation : String) : IdwsUnit;
         procedure DoOnResource(compiler : TdwsCompiler; const resName : String);

         procedure ReExec(info : TProgramInfo);
         procedure HostExcept(info : TProgramInfo);
         procedure RoundTrip(info : TProgramInfo);

         procedure InvalidAddUnit;

      published
         procedure TokenizerErrorTransition;

         procedure ReleaseCompilerBeforeProg;

         procedure TimeOutTestFinite;
         procedure TimeOutTestInfinite;
         procedure TimeOutTestSequence;

         procedure IncludeViaEvent;
         procedure IncludeViaFile;
         procedure IncludeViaFileRestricted;
         procedure IncludeCommentStart;
         procedure IncludeStringStart;
         procedure IncludeInSections;

         procedure RestrictedFileSystem;
         procedure StackMaxRecursion;
         procedure StackOverFlow;
         procedure StackOverFlowOnFuncPtr;
         procedure Assertions;
         procedure ScriptVersion;
         procedure ExecuteParams;
         procedure CallFuncThatReturnsARecord;
         procedure ConfigAssign;
         procedure DestructorCall;
         procedure SubExprTest;
         procedure RecompileInContext;
         procedure RecompileInContext2;
         procedure RecompileInContext3;
         procedure RecompileInContext4;
         procedure RecompileInContextUses;
         procedure RecompileInContextUnit;
//         procedure RecompileInContextVarArray;
         procedure ScriptPos;
         procedure MonkeyTest;
         procedure SameVariantTest;
         procedure SectionContextMaps;
         procedure ResourceTest;
         procedure LongLineTest;
         procedure TryExceptLoop;
         procedure ExternalSubClass;
         procedure DeprecatedTdwsUnit;

         procedure FilterTest;
         procedure SubFilterTest;
         procedure SubFilterEditorModeTest;
         procedure FilterNotDefined;
         procedure FilterEditorMode;

         procedure ConfigNotifications;
         procedure ConfigTimeout;
         procedure CallUnitProcTest;
         procedure NormalizeFloatArrayElements;
         procedure MultiRunProtection;
         procedure MultipleHostExceptions;
         procedure OverloadOverrideIndwsUnit;
         procedure OverloadMissing;
         procedure PartialClassParent;
         procedure ConstantAliasing;
         procedure ExternalVariables;
         procedure ExternalClassVariable;
         procedure TypeOfProperty;
         procedure MethodFree;
         procedure MethodDestroy;
         procedure PropertyDefault;
         procedure SimpleStringListIndexOf;
         procedure ExceptionInInitialization;
         procedure ExceptionInFinalization;
         procedure ErrorInInitialization;
         procedure CaseOfBuiltinHelper;
         procedure CompilerInternals;
         procedure CompilerAbort;
         procedure InitializationFinalization;
         procedure IsAbstractFlag;
         procedure UnitOwnedByCompiler;
         procedure BugInForVarConnectorExpr;
         procedure MultiLineUnixStyle;
         procedure EmptyProgram;
         procedure MessagesToJSON;
         procedure MessagesEnumerator;
         procedure UnitNameTest;
         procedure ExceptionWithinMagic;
         procedure DiscardEmptyElse;
         procedure AnonymousRecordWithConstArrayField;

         procedure Switch_TIMESTAMP;
         procedure Switch_EXEVERSION;

         procedure UnderscoreNumbers;

         procedure DelphiDialectProcedureTypes;

         procedure LambdaAsConstParam;

         procedure RoundTripTest;

         procedure ConstructorOverload;

         procedure EndDot;

         procedure SizeOfSpecial;

         procedure EmptyForLoop;
   end;

   ETestException = class (Exception);

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

function GetTemporaryFilesPath : String;
var
   n: Integer;
begin
   SetLength(Result, MAX_PATH);
   n:=GetTempPath(MAX_PATH-1, PChar(Result));
   SetLength(Result, n);
end;

type
   TScriptThread = class (TdwsThread)
      private
         FProg : IdwsProgram;
         FTimeOut : Integer;
         FTimeStamp : TDateTime;
      public
         constructor Create(const prog : IdwsProgram; timeOut : Integer);
         procedure Execute; override;
   end;

// Create
//
constructor TScriptThread.Create(const prog : IdwsProgram; timeOut : Integer);
begin
   inherited Create(True);
   FProg:=prog;
   FTimeOut:=timeOut;
end;

// Execute
//
procedure TScriptThread.Execute;
begin
   FProg.Execute(FTimeOut);
   FTimeStamp:=Now;
end;

type
   TTestFilter = class(TdwsFilter)
      constructor TestCreate(const s : String);
      function Process(const aText : String; aMsgs : TdwsMessageList) : String; override;
   end;

// TTestFilter
//
constructor TTestFilter.TestCreate(const s : String);
begin
   inherited Create(nil);
   if s<>'' then
      PrivateDependencies.Add(s);
end;

// Process
//
function TTestFilter.Process(const aText : String; aMsgs : TdwsMessageList) : String;
begin
   if EditorMode then begin
      if SubFilter <> nil then
         Result := SubFilter.Process(aText, aMsgs)
      else Result := aText;
      Result := '(' + Result + ')';
   end else Result := inherited Process(aText, aMsgs);
end;

// ------------------
// ------------------ TCornerCasesTests ------------------
// ------------------

// SetUp
//
procedure TCornerCasesTests.SetUp;
var
   roundTripFunc : TdwsFunction;
   roundTripFuncParam : TdwsParameter;
begin
   FCompiler:=TDelphiWebScript.Create(nil);
   FCompiler.OnInclude := DoOnInclude;
   FCompiler.OnNeedUnitEx := DoOnNeedUnit;

   FUnit:=TdwsUnit.Create(nil);
   FUnit.UnitName:='CornerCases';
   FUnit.Functions.Add('ReExec').OnEval:=ReExec;
   FUnit.Functions.Add('HostExcept').OnEval:=HostExcept;

   roundTripFunc := FUnit.Functions.Add('RoundTrip');
   roundTripFunc.ResultType := SYS_STRING;
   roundTripFunc.OnEval := RoundTrip;
   roundTripFuncParam := roundTripFunc.Parameters.Add;
   roundTripFuncParam.Name := 'p';
   roundTripFuncParam.DataType := SYS_STRING;
   roundTripFuncParam := roundTripFunc.Parameters.Add;
   roundTripFuncParam.Name := 'n';
   roundTripFuncParam.DataType := SYS_INTEGER;

   FUnit.Script:=FCompiler;
end;

// TearDown
//
procedure TCornerCasesTests.TearDown;
begin
   FUnit.Free;
   FCompiler.Free;
end;

// TokenizerErrorTransition
//
procedure TCornerCasesTests.TokenizerErrorTransition;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile('var s = $'#25);

   CheckEquals('Syntax Error: Hexadecimal digit expected (found #25) [line: 1, column: 10]'#13#10, prog.Msgs.AsInfo);
end;

// ReleaseCompilerBeforeProg
//
procedure TCornerCasesTests.ReleaseCompilerBeforeProg;
var
   dws : TDelphiWebScript;
   prog : IdwsProgram;
begin
   dws := TDelphiWebScript.Create(nil);
   try
      prog := dws.Compile(' ');
   finally
      try
         dws.Free;
      except
         on E : Exception do begin
            CheckEquals(EdwsActivePrograms, E.ClassType);
            prog := nil;
            dws.Free;
         end;
      end;
   end;
   Check(prog = nil, 'Faield to warn');
end;

// TimeOutTestFinite
//
procedure TCornerCasesTests.TimeOutTestFinite;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile('while false do;');

   prog.TimeoutMilliseconds:=1000;
   prog.Execute;
end;

// TimeOutTestInfinite
//
procedure TCornerCasesTests.TimeOutTestInfinite;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile('while true do;');

   prog.TimeoutMilliseconds:=100;
   prog.Execute;
end;

// TimeOutTestSequence
//
procedure TCornerCasesTests.TimeOutTestSequence;
var
   prog : IdwsProgram;
   threads : array [1..3] of TScriptThread;
   i : Integer;
begin
   prog:=FCompiler.Compile('while true do;');

   for i:=1 to 3 do
      threads[i]:=TScriptThread.Create(prog, i*30);
   for i:=1 to 3 do
      threads[i].Start;
   while (threads[1].FTimeStamp=0) or (threads[2].FTimeStamp=0) or (threads[3].FTimeStamp=0) do
      Sleep(10);

   try
      Check(threads[1].FTimeStamp<threads[2].FTimeStamp, '1 < 2');
      Check(threads[2].FTimeStamp<threads[3].FTimeStamp, '2 < 3');
   finally
      for i:=1 to 3 do
         threads[i].Free;
   end;

   for i:=1 to 3 do
      threads[i]:=TScriptThread.Create(prog, 100-i*30);
   for i:=1 to 3 do
      threads[i].Start;
   while (threads[1].FTimeStamp=0) or (threads[2].FTimeStamp=0) or (threads[3].FTimeStamp=0) do
      Sleep(10);

   try
      Check(threads[1].FTimeStamp>threads[2].FTimeStamp, '1 > 2');
      Check(threads[2].FTimeStamp>threads[3].FTimeStamp, '2 > 3');
   finally
      for i:=1 to 3 do
         threads[i].Free;
   end;
end;

// DoOnInclude
//
procedure TCornerCasesTests.DoOnInclude(const scriptName : String; var scriptSource : String);
begin
   if scriptName='comment.inc' then
      scriptSource:='{'
   else if scriptName='string.inc' then
      scriptSource:='"he'
   else if scriptName='define.test' then
      scriptSource:='{$DEFINE TEST}'
   else begin
      CheckEquals('test.dummy', scriptName, 'DoOnInclude');
      scriptSource:='Print(''hello'');';
   end;
end;

// DoOnNeedUnit
//
function TCornerCasesTests.DoOnNeedUnit(const unitName : String; var unitSource, unitLocation : String) : IdwsUnit;
begin
   if SameText(unitName, 'HelloWorld') then begin
      unitSource := 'unit HelloWorld;';
      unitLocation := 'HelloWorld.pas';
   end else begin
      unitSource := 'error';
   end;
end;

// DoOnResource
//
procedure TCornerCasesTests.DoOnResource(compiler : TdwsCompiler; const resName : String);
begin
   FLastResource:=resName;
   if resName='missing' then
      compiler.Msgs.AddCompilerError(compiler.Tokenizer.HotPos, 'Missing resource')
   else if resName='abort' then
      compiler.AbortCompilation;
end;

// ReExec
//
procedure TCornerCasesTests.ReExec(info : TProgramInfo);
begin
   info.Execution.Execute;
end;

// HostExcept
//
procedure TCornerCasesTests.HostExcept(info : TProgramInfo);
begin
   raise ETestException.Create('boom');
end;

// RoundTrip
//
procedure TCornerCasesTests.RoundTrip(info : TProgramInfo);
var
   func : IInfo;
   n : Integer;
begin
   func := info.RootInfo(info.ParamAsString[0]);
   n := info.ParamAsInteger[1];
   Info.ResultAsString := func.Call([n-1]).ValueAsString;
end;

// IncludeViaEvent
//
procedure TCornerCasesTests.IncludeViaEvent;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   FCompiler.OnInclude:=nil;
   FCompiler.Config.ScriptPaths.Clear;

   prog:=FCompiler.Compile('{$include}');

   CheckEquals('Syntax Error: Name of include file expected [line: 1, column: 10]'#13#10,
               prog.Msgs.AsInfo, 'include missing');

   prog:=FCompiler.Compile('{$include ''test.dummy''}');

   CheckEquals('Compile Error: Could not find file "test.dummy" on input paths [line: 1, column: 11]'#13#10,
               prog.Msgs.AsInfo, 'include forbidden');

   FCompiler.OnInclude:=DoOnInclude;
   prog:=FCompiler.Compile('{$include ''test.dummy''}');

   CheckEquals('', prog.Msgs.AsInfo, 'include via event');
   exec:=prog.Execute;
   CheckEquals('hello', exec.Result.ToString, 'exec include via event');

   prog:=FCompiler.Compile('{$include ''test.dummy''}print(" world");');

   CheckEquals('', prog.Msgs.AsInfo, 'include via event followup');
   exec:=prog.Execute;
   CheckEquals('hello world', exec.Result.ToString, 'exec include via event followup');
end;

// IncludeViaFile
//
procedure TCornerCasesTests.IncludeViaFile;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   sl : TStringList;
   tempDir : String;
   tempFile : String;
begin
   FCompiler.OnInclude:=nil;

   tempDir:=GetTemporaryFilesPath;
   tempFile:=tempDir+'test.dummy';

   sl:=TStringList.Create;
   try
      sl.Add('Print(''world'');');
      sl.SaveToFile(tempFile);
   finally
      sl.Free;
   end;

   FCompiler.Config.ScriptPaths.Clear;
   prog:=FCompiler.Compile('{$include ''test.dummy''}');
   CheckEquals('Compile Error: Could not find file "test.dummy" on input paths [line: 1, column: 11]'#13#10,
               prog.Msgs.AsInfo, 'include via file no paths');

   FCompiler.Config.ScriptPaths.Add(tempDir);
   prog:=FCompiler.Compile('{$include ''test.dummy''}');
   CheckEquals('', prog.Msgs.AsInfo, 'include via file');
   exec:=prog.Execute;
   CheckEquals('world', exec.Result.ToString, 'exec include via file');

   CheckEquals(2, prog.SourceList.Count, 'source list count');
   CheckEquals(MSG_MainModule, prog.SourceList[0].NameReference, 'source list 0');
   CheckEquals('test.dummy', prog.SourceList[1].NameReference, 'source list 1');

   prog:=FCompiler.Compile('{$include ''test.dummy''}print(" happy");');
   CheckEquals('', prog.Msgs.AsInfo, 'include via file followup');
   exec:=prog.Execute;
   CheckEquals('world happy', exec.Result.ToString, 'exec include via file followup');

   FCompiler.Config.ScriptPaths.Clear;
   DeleteFile(tempFile);
end;

// IncludeViaFileRestricted
//
procedure TCornerCasesTests.IncludeViaFileRestricted;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   sl : TStringList;
   tempDir : String;
   tempFile : String;
   restricted : TdwsRestrictedFileSystem;
begin
   restricted:=TdwsRestrictedFileSystem.Create(nil);
   try
      FCompiler.OnInclude:=nil;
      FCompiler.Config.CompileFileSystem:=restricted;

      tempDir:=GetTemporaryFilesPath;
      tempFile:=tempDir+'test.dummy';

      sl:=TStringList.Create;
      try
         sl.Add('Print(''world'');');
         sl.SaveToFile(tempFile);
      finally
         sl.Free;
      end;

      restricted.Paths.Text:=tempDir+'\nothing';
      prog:=FCompiler.Compile('{$include ''test.dummy''}');
      CheckEquals('Compile Error: Could not find file "test.dummy" on input paths [line: 1, column: 11]'#13#10,
                  prog.Msgs.AsInfo, 'include via file missing paths');

      restricted.Paths.Clear;

      prog:=FCompiler.Compile('{$include ''test.dummy''}');
      CheckEquals('Compile Error: Could not find file "test.dummy" on input paths [line: 1, column: 11]'#13#10,
                  prog.Msgs.AsInfo, 'include via file restricted - no paths');

      restricted.Paths.Text:=tempDir;

      FCompiler.Config.ScriptPaths.Add('.');
      prog:=FCompiler.Compile('{$include ''test.dummy''}');
      CheckEquals('', prog.Msgs.AsInfo, 'include via file restricted - dot path');
      exec:=prog.Execute;
      CheckEquals('world', exec.Result.ToString, 'exec include via file');

      DeleteFile(tempFile);
   finally
      restricted.Free;
   end;

   CheckTrue(FCompiler.Config.CompileFileSystem=nil, 'Notification release');
end;

// IncludeCommentStart
//
procedure TCornerCasesTests.IncludeCommentStart;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile('{$include "comment.inc"}');

   CheckEquals( 'Syntax Error: Unexpected end of file (unfinished comment) '
               +'[line: 2, column: 1, file: comment.inc]'#13#10,
               prog.Msgs.AsInfo);
end;

// IncludeStringStart
//
procedure TCornerCasesTests.IncludeStringStart;
var
   prog : IdwsProgram;
begin
   FCompiler.OnInclude:=DoOnInclude;
   prog:=FCompiler.Compile('{$include "string.inc"}');

   CheckEquals( 'Syntax Error: End of string constant not found (end of file) '
               +'[line: 2, column: 1, file: string.inc]'#13#10,
               prog.Msgs.AsInfo);
end;

// IncludeInSections
//
procedure TCornerCasesTests.IncludeInSections;
const
   cCode : String = 'unit Hello;'#13#10
                   +'//1'#13#10
                   +'interface'#13#10
                   +'//2'#13#10
                   +'{$ifdef TEST}procedure World;{$endif}'#13#10
                   +'//3'#13#10
                   +'implementation'#13#10
                   +'//4'#13#10
                   +'{$ifdef TEST}procedure World; begin end;{$endif}'#13#10
                   +'//5'#13#10;
var
   prog : IdwsProgram;
   opts : TCompilerOptions;
   buf : String;
begin
   opts:=FCompiler.Config.CompilerOptions;
   FCompiler.Config.CompilerOptions:=opts+[coSymbolDictionary];
   FCompiler.OnInclude:=DoOnInclude;
   try
      prog:=FCompiler.Compile(cCode);
      CheckEquals('', prog.Msgs.AsInfo, 'Compile default');
      Check(prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration)=nil, 'Check default');

      buf:=cCode;
      FastStringReplace(buf, '//1', '{$include "define.test"}');
      prog:=FCompiler.Compile(buf);
      CheckEquals('', prog.Msgs.AsInfo, 'Compile 1');
      Check(prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration)<>nil, 'Check 1');
      CheckEquals(5, prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration).ScriptPos.Line, 'Line 1');

      buf:=cCode;
      FastStringReplace(buf, '//2', '{$include "define.test"}');
      prog:=FCompiler.Compile(buf);
      CheckEquals('', prog.Msgs.AsInfo, 'Compile 2');
      Check(prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration)<>nil, 'Check 2');
      CheckEquals(5, prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration).ScriptPos.Line, 'Line 2');

      buf:=cCode;
      FastStringReplace(buf, '//3', '{$include "define.test"}');
      prog:=FCompiler.Compile(buf);
      CheckEquals('', prog.Msgs.AsInfo, 'Compile 3');
      Check(prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration)<>nil, 'Check 3');
      CheckEquals(9, prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration).ScriptPos.Line, 'Line 3');

      buf:=cCode;
      FastStringReplace(buf, '//4', '{$include "define.test"}');
      prog:=FCompiler.Compile(buf);
      CheckEquals('', prog.Msgs.AsInfo, 'Compile 4');
      Check(prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration)<>nil, 'Check 4');
      CheckEquals(9, prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration).ScriptPos.Line, 'Line 4');

      buf:=cCode;
      FastStringReplace(buf, '//5', '{$include "define.test"}');
      prog:=FCompiler.Compile(buf);
      CheckEquals('', prog.Msgs.AsInfo, 'Compile 5');
      Check(prog.SymbolDictionary.FindSymbolUsage('World', suDeclaration)=nil, 'Check 5');
   finally
      FCompiler.Config.CompilerOptions:=opts;
   end;
end;

// RestrictedFileSystem
//
procedure TCornerCasesTests.RestrictedFileSystem;
var
   r : TdwsRestrictedFileSystem;
   fs : IdwsFileSystem;
begin
   r := TdwsRestrictedFileSystem.Create(nil);
   try
      r.Paths.Add('c:\www');
      r.Paths.Add('d:\foo\bar\');
      fs := r.AllocateFileSystem;
      CheckNotEquals('', fs.ValidateFileName('hello'), 'hello');
      CheckNotEquals('', fs.ValidateFileName('c:\www\hello'), 'c:\www\hello');
      CheckEquals('', fs.ValidateFileName('c:\www1'), 'c:\www1');
      CheckNotEquals('', fs.ValidateFileName('c:\www\'), 'c:\www\');
      CheckEquals('', fs.ValidateFileName('c:\www'), 'c:\www');
      CheckNotEquals('', fs.ValidateFileName('C:\wWw\world.txt'), 'C:\wWw\world.txt');
      CheckNotEquals('', fs.ValidateFileName('c:\www\abc\xyz\ghi.txt'), 'ghi.txt 1');
      CheckEquals('', fs.ValidateFileName('d:\foo\abc'), 'd:\foo\abc');
      CheckEquals('', fs.ValidateFileName('d:\foo\bars'), 'd:\foo\bars');
      CheckNotEquals('', fs.ValidateFileName('d:\foo\bar\s'), 'd:\foo\bar\s');
      CheckNotEquals('', fs.ValidateFileName('d:\foo\bar\abc\def\ghi.txt'), 'ghi.txt 2');
      CheckEquals('', fs.ValidateFileName('c:\foo\bar\abc\def\ghi.txt'), 'ghi.txt 3');
   finally
      r.Free;
   end;
end;

// StackMaxRecursion
//
procedure TCornerCasesTests.StackMaxRecursion;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   FCompiler.Config.MaxRecursionDepth:=5;

   prog:=FCompiler.Compile('procedure Dummy; begin Dummy; end; Dummy;');
   CheckEquals('', prog.Msgs.AsInfo, 'compile');
   exec:=prog.Execute;
   CheckEquals('Runtime Error: Maximal recursion exceeded (5 calls) [line: 1, column: 24]'#13#10
               +'Dummy [line: 1, column: 24]'#13#10
               +'Dummy [line: 1, column: 24]'#13#10
               +'Dummy [line: 1, column: 24]'#13#10
               +' [line: 1, column: 36]'#13#10,
               exec.Msgs.AsInfo, 'stack max recursion');

   FCompiler.Config.MaxDataSize:=cDefaultMaxRecursionDepth;
end;

// StackOverFlow
//
procedure TCornerCasesTests.StackOverFlow;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   FCompiler.Config.MaxDataSize := 2*SizeOf(Variant);

   prog:=FCompiler.Compile('procedure Dummy; var i : Integer; begin Dummy; end; Dummy;');
   CheckEquals('', prog.Msgs.AsInfo, 'compile');
   exec:=prog.Execute;
   CheckEquals('Runtime Error: Maximal data size exceeded (2 Variants) [line: 1, column: 41]'#13#10
               +'Dummy [line: 1, column: 41]'#13#10
               +' [line: 1, column: 53]'#13#10,
               exec.Msgs.AsInfo, 'stack overflow');

   FCompiler.Config.MaxDataSize:=0;
end;

// StackOverFlowOnFuncPtr
//
procedure TCornerCasesTests.StackOverFlowOnFuncPtr;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   buf, buf2 : String;
   oldOptions : TCompilerOptions;
begin
   oldOptions := FCompiler.Config.CompilerOptions;
   try
      FCompiler.Config.CompilerOptions:=[coSymbolDictionary, coContextMap, coOptimize];

      prog:=FCompiler.Compile( 'type TObj = Class'#13#10
                              +' Procedure Proc;'#13#10
                              +' Begin'#13#10
                              +'  var p := @Proc;'#13#10
                              +'  p;'#13#10
                              +' End;'#13#10
                              +'End;'#13#10
                              +'TObj.Create.Proc;'#13#10);
      CheckEquals('', prog.Msgs.AsInfo, 'compile');
      prog.ProgramObject.MaxRecursionDepth := 128;
      exec:=prog.Execute;
      buf:='TObj.Proc [line: 5, column: 4]'#13#10' [line: 8, column: 13]'#13#10;
      buf2:=exec.Msgs.AsInfo;
      CheckEquals(buf, Copy(buf2, Length(buf2)-Length(buf)+1, MaxInt), 'stack overflow');
   finally
      FCompiler.Config.CompilerOptions := oldOptions;
   end;
end;

// Assertions
//
procedure TCornerCasesTests.Assertions;

   procedure CheckCase(options : TCompilerOptions; const expected, testName : String);
   var
      prog : IdwsProgram;
      exec : IdwsProgramExecution;
   begin
      FCompiler.Config.CompilerOptions:=options;
      prog:=FCompiler.Compile('Assert(False);');
      exec:=prog.Execute;
      CheckEquals(expected, Trim(exec.Msgs.AsInfo), testName);
   end;

begin
   try
      CheckCase([coOptimize, coAssertions], 'Runtime Error: Assertion failed [line: 1, column: 1]', 'assertions optimization');
      CheckCase([coAssertions], 'Runtime Error: Assertion failed [line: 1, column: 1]', 'assertions');
      CheckCase([coOptimize], '', 'optimization');
      CheckCase([], '', 'neither');
   finally
      FCompiler.Config.CompilerOptions:=cDefaultCompilerOptions;
   end;
end;

// ScriptVersion
//
procedure TCornerCasesTests.ScriptVersion;
var
   v : String;
begin
   v:=FCompiler.Version;
   FCompiler.Version:='???';
   CheckEquals(v, FCompiler.Version);
end;

// ExecuteParams
//
procedure TCornerCasesTests.ExecuteParams;
var
   prog : IdwsProgram;
   params : TVariantDynArray;
begin
   prog:=FCompiler.Compile('PrintLn(ParamCount);'
                           +'var i : Integer;'
                           +'if ParamCount>0 then Print(Param(0));'
                           +'for i:=0 to ParamCount-1 do PrintLn(ParamStr(i));');

   CheckEquals('1'#13#10'hello worldhello world'#13#10, prog.ExecuteParam('hello world').Result.ToString);
   CheckEquals('2'#13#10'hellohello'#13#10'world'#13#10, prog.ExecuteParam(VarArrayOf(['hello','world'])).Result.ToString);

   SetLength(params, 0);
   CheckEquals('0'#13#10, prog.ExecuteParam(params).Result.ToString);
   SetLength(params, 1);
   params[0]:='hello';
   CheckEquals('1'#13#10'hellohello'#13#10, prog.ExecuteParam(params).Result.ToString);
   SetLength(params, 2);
   params[1]:=123;
   CheckEquals('2'#13#10'hellohello'#13#10'123'#13#10, prog.ExecuteParam(params).Result.ToString);
end;

// CallFuncThatReturnsARecord
//
procedure TCornerCasesTests.CallFuncThatReturnsARecord;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   result : IInfo;
begin
   prog:=FCompiler.Compile('type TMyRec = record x, y : Integer; end;'
                           +'function Hello : TMyRec;'
                           +'begin Result.x:=1; Result.y:=2; end;');

   exec:=prog.BeginNewExecution;
   try
      result:=exec.Info.Func['Hello'].Call;
      CheckEquals(1, result.Member['x'].ValueAsInteger, 'x');
      CheckEquals(2, result.Member['y'].ValueAsInteger, 'y');
   finally
      exec.EndProgram;
   end;
end;

// ConfigAssign
//
procedure TCornerCasesTests.ConfigAssign;
var
   mds : Integer;
begin
   mds:=FCompiler.Config.MaxDataSize;
   FCompiler.Config:=FCompiler.Config;
   CheckEquals(mds, FCompiler.Config.MaxDataSize);
   FCompiler.Config.ResultType:=FCompiler.Config.ResultType;
end;

// DestructorCall
//
procedure TCornerCasesTests.DestructorCall;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   info : IInfo;
begin
   prog:=FCompiler.Compile( 'type TScriptClass = class'#13#10
                           +'constructor Create;'#13#10
                           +'destructor Destroy; override;'#13#10
                           +'end;'#13#10
                           +'constructor TScriptClass.Create; begin Print(''create''); end;'#13#10
                           +'destructor TScriptClass.Destroy; begin Print(''-destroy''); inherited; end;');

   exec:=prog.BeginNewExecution;
   try
      info:=exec.Info.Vars['TScriptClass'].GetConstructor('Create', nil).Call;
      info.Method['Free'].Call;
      CheckEquals('create-destroy', exec.Result.ToString);
   finally
      exec.EndProgram;
   end;
end;

// SubExprTest
//
procedure TCornerCasesTests.SubExprTest;

   procedure SubExprTree(output : TWriteOnlyBlockStream; const expr : TExprBase; indent : Integer);
   var
      i : Integer;
   begin
      output.WriteString(StringOfChar(#9, indent));
      if expr=nil then
         output.WriteString('nil')
      else output.WriteString(expr.ClassName);
      output.WriteString(#13#10);
      if expr<>nil then
         for i:=0 to expr.SubExprCount-1 do
            SubExprTree(output, expr.SubExpr[i], indent+1);
   end;

   function MakeSubExprTree(const expr : TExprBase) : String;
   var
      sb : TWriteOnlyBlockStream;
   begin
      sb:=TWriteOnlyBlockStream.Create;
      try
         SubExprTree(sb, expr, 0);
         Result:=sb.ToString;
      finally
         sb.Free;
      end;
   end;

var
   prog : IdwsProgram;
   testFuncSym : TSourceFuncSymbol;
begin
   prog:=FCompiler.Compile( 'function Test(a : Integer) : Integer;'#13#10
                           +'begin'#13#10
                           +'Result:=a+1;'#13#10
                           +'end;'#13#10
                           +'var s := "Hello";'#13#10
                           +'Print(s);'#13#10
                           +'if s<>"" then Print(Test(5));');


   testFuncSym:=(prog.Table.FindSymbol('Test', cvMagic) as TSourceFuncSymbol);
   CheckEquals(2, testFuncSym.SubExprCount, 'Test SubExprCount');
   CheckEquals('TBlockInitExpr'#13#10,
               MakeSubExprTree(testFuncSym.SubExpr[0]), 'Test InitExpr');
   CheckEquals('TAssignExpr'#13#10
                  +#9'TIntVarExpr'#13#10
                  +#9'TAddIntExpr'#13#10
                     +#9#9'TIntVarExpr'#13#10
                     +#9#9'TConstIntExpr'#13#10,
               MakeSubExprTree(testFuncSym.SubExpr[1]), 'Test Expr');

   CheckEquals('TBlockInitExpr'#13#10
                  +#9'TInitDataExpr'#13#10
                     +#9#9'TStrVarExpr'#13#10,
               MakeSubExprTree((prog.GetSelf as TdwsProgram).InitExpr), 'Main InitExpr');
   CheckEquals('TBlockExprNoTable3'#13#10
                  +#9'TAssignConstToStringVarExpr'#13#10
                     +#9#9'TStrVarExpr'#13#10
                     +#9#9'nil'#13#10
                  +#9'TMagicProcedureExpr'#13#10
                     +#9#9'TStrVarExpr'#13#10
                  +#9'TIfThenExpr'#13#10
                     +#9#9'TRelNotEqualStringExpr'#13#10
                        +#9#9#9'TStrVarExpr'#13#10
                        +#9#9#9'TConstStringExpr'#13#10
                     +#9#9'TMagicProcedureExpr'#13#10
                        +#9#9#9'TFuncSimpleExpr'#13#10
                           +#9#9#9#9'TConstIntExpr'#13#10,
               MakeSubExprTree((prog.GetSelf as TdwsProgram).Expr), 'Main Expr');
end;

// RecompileInContext
//
procedure TCornerCasesTests.RecompileInContext;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile('const hello = "world"; Print("hello");');

   CheckEquals(0, prog.Msgs.Count, 'Compile: '+prog.Msgs.AsInfo);
   exec:=prog.Execute;
   CheckEquals('hello', exec.Result.ToString, 'Compile Result');

   FCompiler.RecompileInContext(prog, 'Print(hello);');

   CheckEquals(0, prog.Msgs.Count, 'Recompile: '+prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('world', exec.Result.ToString, 'Recompile Result');
end;

// RecompileInContext2
//
procedure TCornerCasesTests.RecompileInContext2;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'type TTest = class '
                              +'constructor Create;'
                              +'procedure Test;'
                           +'end;'
                           +'var t : TTest;'
                           +'constructor TTest.Create; begin t:=Self; end;'
                           +'procedure TTest.Test; begin Print(ClassName); end;'
                           +'TTest.Create;'
                           );

   CheckEquals(0, prog.Msgs.Count, 'Compile: '+prog.Msgs.AsInfo);

   exec:=prog.BeginNewExecution;
   try

      exec.RunProgram(0);

      CheckEquals('', exec.Result.ToString, 'Compile Result');

      FCompiler.RecompileInContext(prog, 't.Test;');

      CheckEquals(0, prog.Msgs.Count, 'Recompile: '+prog.Msgs.AsInfo);

      exec.RunProgram(0);

      CheckEquals('TTest', exec.Result.ToString, 'Recompile Result');

   finally
      exec.EndProgram;
   end;
end;

// RecompileInContext3
//
procedure TCornerCasesTests.RecompileInContext3;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'Print("Hello");'
                           +'var x: Integer;');

   exec:=prog.BeginNewExecution;

   exec.RunProgram(0);
   CheckEquals('Hello', exec.Result.ToString, 'compile');

   FCompiler.RecompileInContext(prog, 'x := 2; Print(x);');
   exec.RunProgram(0);
   CheckEquals('Hello2', exec.Result.ToString, 're compile');

   FCompiler.RecompileInContext(prog, 'x:=x+1; Print(x);');
   exec.RunProgram(0);
   CheckEquals('Hello23', exec.Result.ToString, 're re compile');

   exec.EndProgram;
end;

// RecompileInContext4
//
procedure TCornerCasesTests.RecompileInContext4;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'Print("Hello");');

   exec:=prog.BeginNewExecution;
   try

      FCompiler.RecompileInContext(prog, 'var x := 2');
      exec.RunProgram(0);
      CheckEquals('', exec.Result.ToString, 'compile');

      FCompiler.RecompileInContext(prog, 'Print(x)');
      exec.RunProgram(0);
      CheckEquals('2', exec.Result.ToString, 're compile');

      FCompiler.RecompileInContext(prog, 'var y := x+1; Print(y);');
      exec.RunProgram(0);
      CheckEquals('23', exec.Result.ToString, 're re compile');

   finally
      exec.EndProgram;
   end;
end;
(*
procedure TCornerCasesTests.RecompileInContextVarArray;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;

   procedure Run(Line, Check: string);
   begin
      FCompiler.RecompileInContext(prog, Line);
      exec.RunProgram(0);
      CheckEquals(Check, exec.Result.ToString, 're compile line: "' + Line + '"');
   end;

begin
   prog:=FCompiler.Compile('Print("Recompile Array of Integer");'#10
                         + 'var j : array of integer;');

   exec:=prog.BeginNewExecution;
   try
//      Run('j.add(56);', '');
      Run('var i : array of integer;', '');
      Run('i.add(78);', '');
      Run('Print(i[0]);', '78');
   finally
      exec.EndProgram;
   end;
end;
*)

// RecompileInContextUses
//
procedure TCornerCasesTests.RecompileInContextUses;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog := FCompiler.Compile( 'uses HelloWorld; Print(1);');

   exec:=prog.BeginNewExecution;
   try
      exec.RunProgram(0);
      CheckEquals('1', exec.Result.ToString, 'compile 1');
   finally
      exec.EndProgram;
   end;

   FCompiler.RecompileInContext(prog, 'uses HelloWorld; Print(2);');

   exec:=prog.BeginNewExecution;
   try
      exec.RunProgram(0);
      CheckEquals('2', exec.Result.ToString, 'compile 2');
   finally
      exec.EndProgram;
   end;

   FCompiler.RecompileInContext(prog, 'uses HelloWorld; Print(3);');

   exec:=prog.BeginNewExecution;
   try
      exec.RunProgram(0);
      CheckEquals('3', exec.Result.ToString, 're compile 3');
   finally
      exec.EndProgram;
   end;
end;

// RecompileInContextUnit
//
procedure TCornerCasesTests.RecompileInContextUnit;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog := FCompiler.Compile( 'unit Recomp; uses HelloWorld; Print(1);');

   exec:=prog.BeginNewExecution;
   try
      exec.RunProgram(0);
      CheckEquals('1', exec.Result.ToString, 'compile 1');
   finally
      exec.EndProgram;
   end;

   FCompiler.RecompileInContext(prog, 'unit Recomp; uses HelloWorld; Print(2);');
   CheckEquals('Syntax Error: RecompileInContect does not support units [line: 1, column: 1]'#13#10, prog.Msgs.AsInfo);
end;

// ScriptPos
//
procedure TCornerCasesTests.ScriptPos;
var
   p : TScriptPos;
begin
   p:=TScriptPos.Create(nil, 1, 2);

   CheckFalse(p.IsSourceFile('test'));
   CheckEquals('', p.AsInfo);

   CheckEquals(1, p.Line);
   CheckEquals(2, p.Col);

   p.IncCol;

   CheckEquals(1, p.Line);
   CheckEquals(3, p.Col);

   p.NewLine;

   CheckEquals(2, p.Line);
   CheckEquals(1, p.Col);
end;

// MonkeyTest
//
procedure TCornerCasesTests.MonkeyTest;
var
   i, n : Integer;
   s : String;
   prog : IdwsProgram;
   tt : TTokenType;
begin
   RandSeed:=0;

   for i:=1 to 2000 do begin
      n:=Random(10)+2;
      s:='';
      while n>0 do begin
         tt:=TTokenType(Random(Ord(High(TTokenType))+1));
         s:=s+cTokenStrings[tt]+' ';
         Dec(n);
      end;
      prog:=FCompiler.Compile(s);
   end;
end;

// SameVariantTest
//
procedure TCornerCasesTests.SameVariantTest;
var
   v : Variant;
begin
   CheckFalse(DWSSameVariant('hello', 123), '"hello" 123');

   CheckFalse(DWSSameVariant('123', 123), '"123" 123');
   CheckFalse(DWSSameVariant(123, '123'), '123 "123"');

   CheckFalse(DWSSameVariant(True, False), 'True False');
   CheckFalse(DWSSameVariant(False, True), 'False True');
   CheckTrue(DWSSameVariant(True, True), 'True True');
   CheckTrue(DWSSameVariant(False, False), 'True True');

   v:=1.5;
   CheckTrue(DWSSameVariant(v, v), 'v v');

   v:=Null;
   CheckTrue(DWSSameVariant(v, Null), 'Null Null');
   CheckFalse(DWSSameVariant(v, 1), 'Null 1');
end;

// SectionContextMaps
//
procedure TCornerCasesTests.SectionContextMaps;
var
   prog : IdwsProgram;
   unitContext, context : TdwsSourceContext;
   writer : TdwsJSONBeautifiedWriter;
   wobs : TWriteOnlyBlockStream;
begin
   FCompiler.Config.CompilerOptions:=[coContextMap];
   prog:=FCompiler.Compile( 'unit dummy;'#13#10
                           +'interface;'#13#10
                           +'uses Internal;'#13#10
                           +'implementation;'#13#10);
   FCompiler.Config.CompilerOptions:=cDefaultCompilerOptions;

   unitContext:=prog.SourceContextMap.FindContextByToken(ttUNIT);
   CheckNotNull(unitContext, 'unit map');
   CheckNotNull(unitContext.ParentSym, 'unit parentsym');
   CheckEquals('dummy', unitContext.ParentSym.Name, 'unit parentsym name');

   context:=unitContext.FindContextByToken(ttINTERFACE);
   CheckEquals(' [line: 2, column: 1]', context.StartPos.AsInfo, 'intf start');
   CheckEquals(' [line: 4, column: 1]', context.EndPos.AsInfo, 'intf end');
   CheckEquals(1, context.Count, 'intf sub count');

   context:=unitContext.SubContext[0].SubContext[0];
   CheckEquals(Ord(ttUSES), Ord(context.Token), 'uses token');
   CheckEquals(' [line: 3, column: 1]', context.StartPos.AsInfo, 'uses start');
   CheckEquals(' [line: 3, column: 14]', context.EndPos.AsInfo, 'uses end');

   context:=unitContext.FindContextByToken(ttIMPLEMENTATION);
   CheckEquals(' [line: 4, column: 1]', context.StartPos.AsInfo, 'implem start');
   CheckEquals(' [line: 6, column: 1]', context.EndPos.AsInfo, 'implem end');
   CheckEquals(0, context.Count, 'implem sub count');

   wobs:=TWriteOnlyBlockStream.Create;
   writer:=TdwsJSONBeautifiedWriter.Create(wobs, 0, 1);
   try
      prog.SourceContextMap.WriteToJSON(writer);
      CheckEquals( '['#13#10
                  +#9'{'#13#10
                  +#9#9'"Token" : "ttUNIT",'#13#10
                  +#9#9'"Symbol" : {'#13#10
                  +#9#9#9'"Class" : "TUnitMainSymbol",'#13#10
                  +#9#9#9'"Name" : "dummy"'#13#10
                  +#9#9'},'#13#10
                  +#9#9'"SubContexts" : ['#13#10
                  +#9#9#9'{'#13#10
                  +#9#9#9#9'"Token" : "ttINTERFACE",'#13#10
                  +#9#9#9#9'"Symbol" : {'#13#10
                  +#9#9#9#9#9'"Class" : "TUnitMainSymbol",'#13#10
                  +#9#9#9#9#9'"Name" : "dummy"'#13#10
                  +#9#9#9#9'},'#13#10
                  +#9#9#9#9'"SubContexts" : ['#13#10
                  +#9#9#9#9#9'{'#13#10
                  +#9#9#9#9#9#9'"Token" : "ttUSES",'#13#10
                  +#9#9#9#9#9#9'"Symbol" : null,'#13#10
                  +#9#9#9#9#9#9'"SubContexts" : [ ],'#13#10
                  +#9#9#9#9#9#9'"Start" : " [line: 3, column: 1]",'#13#10
                  +#9#9#9#9#9#9'"End" : " [line: 3, column: 14]"'#13#10
                  +#9#9#9#9#9'}'#13#10
                  +#9#9#9#9'],'#13#10
                  +#9#9#9#9'"Start" : " [line: 2, column: 1]",'#13#10
                  +#9#9#9#9'"End" : " [line: 4, column: 1]"'#13#10
                  +#9#9#9'},'#13#10
                  +#9#9#9'{'#13#10
                  +#9#9#9#9'"Token" : "ttIMPLEMENTATION",'#13#10
                  +#9#9#9#9'"Symbol" : {'#13#10
                  +#9#9#9#9#9'"Class" : "TUnitMainSymbol",'#13#10
                  +#9#9#9#9#9'"Name" : "dummy"'#13#10
                  +#9#9#9#9'},'#13#10
                  +#9#9#9#9'"SubContexts" : [ ],'#13#10
                  +#9#9#9#9'"Start" : " [line: 4, column: 1]",'#13#10
                  +#9#9#9#9'"End" : " [line: 6, column: 1]"'#13#10
                  +#9#9#9'}'#13#10
                  +#9#9'],'#13#10
                  +#9#9'"Start" : " [line: 1, column: 1]",'#13#10
                  +#9#9'"End" : " [line: 6, column: 1]"'#13#10
                  +#9'}'#13#10
                  +']',
                  wobs.ToString, 'JSON map');
   finally
      writer.Free;
      wobs.Free;
   end;
end;

// ResourceTest
//
procedure TCornerCasesTests.ResourceTest;
var
   prog : IdwsProgram;
begin
   FLastResource:='';
   prog:=FCompiler.Compile('{$R "hello"}');
   CheckEquals('', FLastResource);

   FCompiler.OnResource:=DoOnResource;

   prog:=FCompiler.Compile('{$R "hello"}');
   CheckEquals('hello', FLastResource);

   prog:=FCompiler.Compile('{$RESOURCE ''world''}');
   CheckEquals('world', FLastResource);

   prog:=FCompiler.Compile('{$R "hello'#13#10'world"}');
   CheckEquals('hello'#13#10'world', FLastResource);

   prog:=FCompiler.Compile('{$R "missing"}');
   CheckEquals('Syntax Error: Missing resource [line: 1, column: 5]'#13#10, prog.Msgs.AsInfo);

   FCompiler.OnResource:=nil;
end;

// LongLineTest
//
procedure TCornerCasesTests.LongLineTest;
var
   s : String;
   prog : IdwsProgram;
begin
   s:='var s:="'+StringOfChar('a', 6000)+'";bug';

   prog:=FCompiler.Compile(s);
   CheckEquals('Syntax Error: Unknown name "bug" [line: 1, column: 6011]'#13#10, prog.Msgs.AsInfo);
end;

// TryExceptLoop
//
procedure TCornerCasesTests.TryExceptLoop;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'Procedure Proc;'#13#10
                           +'Begin'#13#10
                           +' Try'#13#10
                           +'  Raise Exception.Create("");'#13#10
                           +' Except'#13#10
                           +'  Proc;'#13#10
                           +' End;'#13#10
                           +'End;'#13#10
                           +'Proc;');

   exec:=prog.CreateNewExecution;
   try
      exec.Execute;
      CheckEquals('Runtime Error: Maximal exception depth exceeded (11 nested exceptions) [line: 4, column: 29]'#13#10
                  +' [line: 9, column: 1]'#13#10,
                  exec.Msgs.AsInfo,
                  'exception depth');
   finally
      exec:=nil;
   end;
end;

// ExternalSubClass
//
procedure TCornerCasesTests.ExternalSubClass;
var
   prog : IdwsProgram;
   subSym : TClassSymbol;
begin
   prog:=FCompiler.Compile( 'type TExt = class external end;'#13#10
                           +'type TSub = class (TExt) end;'#13#10
                           +'type TSub2 = class external (TExt) end;');

   CheckEquals(0, prog.Msgs.Count, prog.Msgs.AsInfo);
   subSym:=(prog.Table.FindLocal('TSub') as TClassSymbol);
   Check(not subSym.IsExternal, 'sub is not external');
   Check(subSym.ExternalRoot.IsExternal, 'sub is externally rooted');

   subSym:=(prog.Table.FindLocal('TSub2') as TClassSymbol);
   Check(subSym.IsExternal, 'sub2 is external');
   Check(subSym.ExternalRoot=subSym, 'sub2 external root is self');

   prog:=FCompiler.Compile( 'type TInt = class end;'#13#10
                           +'type TSub = class external (TInt) end;');
   CheckNotEquals(0, prog.Msgs.Count, prog.Msgs.AsInfo);
end;

// DeprecatedTdwsUnit
//
procedure TCornerCasesTests.DeprecatedTdwsUnit;
var
   un : TdwsUnit;
   prog : IdwsProgram;
   oldOptions : TCompilerOptions;
begin
   oldOptions:=FCompiler.Config.CompilerOptions;
   un:=TdwsUnit.Create(nil);
   try
      un.UnitName:='Hello';
      un.DeprecatedMessage:='world';

      un.Script:=FCompiler;

      FCompiler.Config.CompilerOptions:=oldOptions+[coExplicitUnitUses];
      prog:=FCompiler.Compile('uses Hello;');

      CheckEquals('Warning: "Hello" has been deprecated: world [line: 1, column: 6]'#13#10, prog.Msgs.AsInfo);

      prog:=nil;
   finally
      FCompiler.Config.CompilerOptions:=oldOptions;
      un.Free;
   end;
end;

// FilterTest
//
procedure TCornerCasesTests.FilterTest;
var
   filter : TTestFilter;
var
   prog : IdwsProgram;
begin
   filter:=TTestFilter.TestCreate('');
   FCompiler.OnInclude:=DoOnInclude;
   FCompiler.Config.Filter:=filter;
   try
      prog:=FCompiler.Compile('{$F "test.dummy"}');
      CheckEquals('', prog.Msgs.AsInfo);
      CheckEquals('hello', prog.Execute.Result.ToString);

      prog:=FCompiler.Compile('{$F "test.dummy"');
      CheckEquals('Syntax Error: "}" expected [line: 1, column: 5]'#13#10, prog.Msgs.AsInfo);
   finally
      FCompiler.OnInclude:=nil;
      filter.Free;
   end;
end;

// SubFilterTest
//
procedure TCornerCasesTests.SubFilterTest;
var
   filter1, filter2 : TTestFilter;
begin
   filter1:=TTestFilter.TestCreate('abc');
   filter2:=TTestFilter.TestCreate('def');
   filter1.SubFilter:=filter2;
   CheckEquals('abc,def', filter1.Dependencies.CommaText, 'dependencies 1+2');
   CheckEquals('test', filter1.Process('test', nil), 'filter');
   filter1.SubFilter:=nil;
   CheckEquals('abc', filter1.Dependencies.CommaText, 'dependencies 2');
   filter1.SubFilter:=filter2;
   filter2.Free;
   CheckTrue(filter1.SubFilter=nil);
   filter1.Free;
end;

// SubFilterEditorModeTest
//
procedure TCornerCasesTests.SubFilterEditorModeTest;
var
   filter1, filter2 : TTestFilter;
begin
   filter1:=TTestFilter.TestCreate('abc');
   filter2:=TTestFilter.TestCreate('def');
   filter1.SubFilter:=filter2;
   try
      CheckEquals('hello', filter1.Process('hello', nil), 'regular');
      filter1.BeginEditorMode;
      try
         CheckEquals('((hello))', filter1.Process('hello', nil), 'editor mode');
      finally
         filter1.EndEditorMode;
      end;
      filter2.BeginEditorMode;
      try
         CheckEquals('(hello)', filter1.Process('hello', nil), 'editor mode');
      finally
         filter2.EndEditorMode;
      end;
   finally
      filter2.Free;
      filter1.Free;
   end;
end;

// FilterNotDefined
//
procedure TCornerCasesTests.FilterNotDefined;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile('{$F "foo.bar"}');

   CheckEquals('Syntax Error: There is no filter assigned to TDelphiWebScriptII.Config.Filter [line: 1, column: 5]'#13#10, prog.Msgs.AsInfo);
end;

// FilterEditorMode
//
procedure TCornerCasesTests.FilterEditorMode;
var
   f : TdwsFilter;
begin
   f := TdwsFilter.Create(nil);
   try
      CheckFalse(f.EditorMode, 'before');
      f.BeginEditorMode;
      CheckTrue(f.EditorMode, 'during 1');
      f.BeginEditorMode;
      CheckTrue(f.EditorMode, 'during 2');
      f.EndEditorMode;
      CheckTrue(f.EditorMode, 'during 1bis');
      f.EndEditorMode;
      CheckFalse(f.EditorMode, 'after');
   finally
      f.Free;
   end;
end;

// ConfigNotifications
//
procedure TCornerCasesTests.ConfigNotifications;
var
   rfs : TdwsNoFileSystem;
   rt : TdwsResultType;
begin
   rfs:=TdwsNoFileSystem.Create(nil);
   rt:=TdwsResultType.Create(nil);
   FCompiler.Config.RuntimeFileSystem:=rfs;
   FCompiler.Config.ResultType:=rt;
   CheckTrue(FCompiler.Config.RuntimeFileSystem<>nil, 'rfs set');
   CheckTrue(FCompiler.Config.ResultType<>nil, 'rt set');
   rt.Free;
   rfs.Free;
   CheckTrue(FCompiler.Config.RuntimeFileSystem=nil, 'rfs cleared');
   CheckTrue(FCompiler.Config.ResultType is TdwsDefaultResultType, 'rt cleared');
end;

// ConfigTimeout
//
procedure TCornerCasesTests.ConfigTimeout;
begin
   CheckEquals(0, FCompiler.Config.TimeoutMilliseconds, 'init');
   FCompiler.Config.TimeOut:=2;
   CheckEquals(2000, FCompiler.Config.TimeoutMilliseconds, 'timeout');
   FCompiler.Config.TimeOut:=0;
   CheckEquals(0, FCompiler.Config.TimeoutMilliseconds, 'cleanup');
end;

// CallUnitProcTest
//
procedure TCornerCasesTests.CallUnitProcTest;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   func : IInfo;
begin
   prog:=FCompiler.Compile( 'unit test;'#13#10
                           +'interface'#13#10
                           +'procedure Test;'#13#10
                           +'implementation'#13#10
                           +'procedure Test;'#13#10
                           +'var myvar : Integer;'#13#10
                           +'begin'#13#10
                           +'   myVar := 1;'#13#10
                           +'   myVar:=2*myvar-StrToInt(IntToStr(myvar));'#13#10
                           +'   PrintLn(myVar);'#13#10
                           +'end;'#13#10
                           +'end.'#13#10);
   exec:=prog.BeginNewExecution;
   func:=exec.Info.Func['Test'];
   func.Call;
   exec.EndProgram;
end;

// NormalizeFloatArrayElements
//
procedure TCornerCasesTests.NormalizeFloatArrayElements;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   a : IInfo;
begin
   prog:=FCompiler.Compile( 'type TFloat2 = array [0..1] of Float;'#13#10
                           +'var a : TFloat2 = [ 1, 2 ];');
   exec:=prog.BeginNewExecution;
   try
      a:=exec.Info.Vars['a'];
      CheckTrue(VarIsFloat(a.Element([0]).Value), 'before 0');
      CheckTrue(VarIsFloat(a.Element([1]).Value), 'before 1');

      exec.RunProgram(0);

      CheckTrue(VarIsFloat(a.Element([0]).Value), 'after 0');
      CheckTrue(VarIsFloat(a.Element([1]).Value), 'after 1');

      CheckEquals(1.0, exec.ExecutionObject.Stack.Data[0]);
      CheckEquals(2.0, exec.ExecutionObject.Stack.Data[1]);

   finally
      exec.EndProgram;
   end;
end;

// MultiRunProtection
//
procedure TCornerCasesTests.MultiRunProtection;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'var o := new TObject;'#13#10
                           +'ReExec;'#13#10
                           +'Print(''Here'');');
   CheckEquals('', prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('Runtime Error: Script is already running'#13#10, exec.Msgs.AsInfo);
   CheckEquals('Here', exec.Result.ToString);
end;

// MultipleHostExceptions
//
procedure TCornerCasesTests.MultipleHostExceptions;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'try HostExcept; except Print("gobbled"); end;'#13#10
                           +'HostExcept;'#13#10);
   CheckEquals('', prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('Runtime Error: boom in HostExcept [line: 2, column: 1]'#13#10, exec.Msgs.AsInfo);
   CheckEquals('gobbled', exec.Result.ToString);
end;

// OverloadOverrideIndwsUnit
//
procedure TCornerCasesTests.OverloadOverrideIndwsUnit;
var
   un : TdwsUnit;
   cls : TdwsClass;
   cst : TdwsConstructor;
   prog : IdwsProgram;
begin
   un:=TdwsUnit.Create(nil);
   try
      un.Name := 'dwsUnitTest';
      un.UnitName := 'TestUnit';
      un.Script := FCompiler;

      cls:=un.Classes.Add;
      cls.Name := 'TClassA';
      cls.IsAbstract := True;

      cst:=cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Attributes := [maVirtual, maAbstract];
      cst.Overloaded := True;
      cst.Parameters.Add('Test', 'Float');

      cst:=cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Attributes := [maVirtual, maAbstract];
      cst.Overloaded := True;
      cst.Parameters.Add('Test', 'Float');
      cst.Parameters.Add('B', 'Integer');

      cls:=un.Classes.Add;
      cls.Name := 'TClassB';
      cls.Ancestor := 'TClassA';

      cst:=cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Attributes := [maOverride];
      cst.Overloaded := True;
      cst.Parameters.Add('Test', 'Float');

      cst:=cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Attributes := [maOverride];
      cst.Overloaded := True;
      cst.Parameters.Add('Test', 'Float');
      cst.Parameters.Add('B', 'Integer');

      prog := FCompiler.Compile('');
      CheckEquals('', prog.Msgs.AsInfo);
      prog := nil;
   finally
      un.Free;
   end;
end;

// OverloadMissing
//
procedure TCornerCasesTests.OverloadMissing;
const
   cCase1 =  'type TTest = class'#10
              + 'procedure Hello;'#10
              + 'procedure Hello(i : Integer); overload; begin end;'#10
           + 'end;'#10
           + 'procedure TTest.Hello; begin end;';
   cCase2 =  'type TTest = class'#10
              + 'procedure Hello(i : Integer); overload; begin end;'#10
              + 'procedure Hello;'#10
           + 'end;'#10
           + 'procedure TTest.Hello; begin end;';
var
   prog : IdwsProgram;
   opts : TCompilerOptions;
begin
   opts := FCompiler.Config.CompilerOptions;
   try
      FCompiler.Config.CompilerOptions := opts - [ coMissingOverloadedAsErrors ];

      prog := FCompiler.Compile(cCase1);
      CheckEquals('Hint: Overloaded method "Hello" should be marked with the "overload" directive [line: 2, column: 11]', Trim(prog.Msgs.AsInfo));
      prog := FCompiler.Compile(cCase2);
      CheckEquals('Hint: Overloaded method "Hello" should be marked with the "overload" directive [line: 3, column: 11]', Trim(prog.Msgs.AsInfo));

      FCompiler.Config.CompilerOptions := opts + [ coMissingOverloadedAsErrors ];

      prog := FCompiler.Compile(cCase1);
      CheckEquals('Syntax Error: Overloaded method "Hello" must be marked with the "overload" directive [line: 2, column: 11]', Trim(prog.Msgs.AsInfo));
      prog := FCompiler.Compile(cCase2);
      CheckEquals('Syntax Error: Overloaded method "Hello" must be marked with the "overload" directive [line: 3, column: 11]', Trim(prog.Msgs.AsInfo));
   finally
      FCompiler.Config.CompilerOptions := opts;
   end;
end;

// PartialClassParent
//
procedure TCornerCasesTests.PartialClassParent;
var
   prog : IdwsProgram;
   cls : TClassSymbol;
begin
   prog:=FCompiler.Compile( 'type TTest = partial class;'#13#10
                           +'type TTest = partial class Field1 : Integer; end;'#13#10
                           +'type TTest = partial class Field2 : Integer; end;'#13#10);

   CheckEquals('', prog.Msgs.AsInfo, 'compile');

   cls:=prog.Table.FindTypeLocal('TTest') as TClassSymbol;

   CheckEquals(2, cls.Members.Count, 'members');
   Check(cls.Parent<>nil, 'Parent not nil');
   CheckEquals('TObject', cls.Parent.Name, 'Parent name');
end;

// ConstantAliasing
//
procedure TCornerCasesTests.ConstantAliasing;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile( 'type TZ = Integer;'#13#10
                           +'const z = TZ(0);'#13#10
                           +'var a : array [0..1] of Integer;');

   CheckEquals('', prog.Msgs.AsInfo);
end;

// ExternalVariables
//
procedure TCornerCasesTests.ExternalVariables;
var
   prog : IdwsProgram;
   sym : TSymbol;
begin
   prog:=FCompiler.Compile(  'var a external "alpha" : String;'#13#10
                           + 'var b external ''123'', c : Integer;'#13#10
                           + 'var d external := False;'#13#10
                           + 'procedure Test; begin var e external "gamma" : Float; end;');

   CheckEquals(  'Syntax Error: String expected [line: 3, column: 16]'#13#10
               + 'Syntax Error: External variables must be global [line: 4, column: 29]'#13#10,
               prog.Msgs.AsInfo);

   sym:=prog.Table.FindSymbol('a', cvMagic);
   CheckEquals(TVarDataSymbol.ClassName, sym.ClassType.ClassName, 'a');
   CheckTrue(TDataSymbol(sym).HasExternalName, 'a');
   CheckEquals('alpha', TDataSymbol(sym).ExternalName, 'a');

   sym:=prog.Table.FindSymbol('b', cvMagic);
   CheckEquals(TVarDataSymbol.ClassName, sym.ClassType.ClassName, 'b');
   Check(TDataSymbol(sym).HasExternalName, 'b');
   CheckEquals('123', TDataSymbol(sym).ExternalName, 'b');

   sym:=prog.Table.FindSymbol('c', cvMagic);
   CheckEquals(TVarDataSymbol.ClassName, sym.ClassType.ClassName, 'c');
   CheckFalse(TDataSymbol(sym).HasExternalName, 'c');
   CheckEquals('c', TDataSymbol(sym).ExternalName, 'c');
end;

// ExternalClassVariable
//
procedure TCornerCasesTests.ExternalClassVariable;
var
   prog : IdwsProgram;
   sym : TSymbol;
begin
   prog:=FCompiler.Compile('type TTest = class'#13#10
                           +'class var a external "alpha" : String;'#13#10
                           +'end;');

   CheckEquals('', prog.Msgs.AsInfo);

   sym:=prog.Table.FindSymbol('TTest', cvMagic);
   CheckEquals(TClassSymbol.ClassName, sym.ClassType.ClassName, 'TTest');

   sym:=TClassSymbol(sym).Members.FindSymbol('a', cvMagic);
   CheckEquals(TClassVarSymbol.ClassName, sym.ClassType.ClassName, 'a');
   Check(TClassVarSymbol(sym).HasExternalName, 'alpha');
end;

// TypeOfProperty
//
procedure TCornerCasesTests.TypeOfProperty;
var
   prog : IdwsProgram;
   sym : TSymbol;
   cls : TClassSymbol;
begin
   prog:=FCompiler.Compile( 'type TColor = Integer;'#13#10
                           +'type TTest = class'#13#10
                           +'Field : TColor;'#13#10
                           +'property Prop : TColor read Field;'#13#10
                           +'property Prop2 : TColor;'#13#10
                           +'end;');

   CheckEquals('', prog.Msgs.AsInfo);

   sym:=prog.Table.FindSymbol('TTest', cvMagic);
   CheckTrue(sym is TClassSymbol, 'is class');

   cls:=TClassSymbol(sym);

   sym:=cls.Members.FindSymbol('Prop', cvMagic);
   CheckEquals('TColor', sym.Typ.Name, 'Prop');

   sym:=cls.Members.FindSymbol('Prop2', cvMagic);
   CheckEquals('TColor', sym.Typ.Name, 'Prop2');
end;

// MethodFree
//
procedure TCornerCasesTests.MethodFree;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'var toto : string = "test";'#13#10
                           +'type tobj = class(Tobject)'#13#10
                           +'Destructor destroy;override;'#13#10
                           +'begin Print(toto) end;'#13#10
                           +'end;'#13#10
                           +'tobj.create.free;');

   CheckEquals('', prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('test', exec.Result.ToString);
end;

// MethodDestroy
//
procedure TCornerCasesTests.MethodDestroy;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'var toto : string = "test";'#13#10
                           +'type tobj = class(Tobject)'#13#10
                           +'Destructor destroy;override;'#13#10
                           +'begin Print(toto) end;'#13#10
                           +'end;'#13#10
                           +'procedure Test; begin var o := tobj.create; end;'#13#10
                           +'Test');

   CheckEquals('', prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('test', exec.Result.ToString);
end;

// PropertyDefault
//
procedure TCornerCasesTests.PropertyDefault;
var
   prog : IdwsProgram;
   cls : TClassSymbol;
   prop : TPropertySymbol;
   buf : String;
begin
   prog:=FCompiler.Compile( 'type tobj = class(Tobject)'#13#10
                           +'Field : String;'#13#10
                           +'property Prop : String read Field default "hello";'#13#10
                           +'end;');

   CheckEquals('', prog.Msgs.AsInfo);

   cls:=prog.Table.FindTypeLocal('tobj') as TClassSymbol;

   prop:=cls.Members.FindSymbol('Prop', cvMagic) as TPropertySymbol;

   CheckEquals('String', prop.DefaultSym.Typ.Name);

   prop.DefaultSym.DataContext.EvalAsString(0, buf);
   CheckEquals('hello', buf);
end;

// SimpleStringListIndexOf
//
procedure TCornerCasesTests.SimpleStringListIndexOf;
var
   ssl : TSimpleStringList;
begin
   ssl:=TSimpleStringList.Create;
   try
      Check(ssl.IndexOf('a')<0, 'empty');
      ssl.Add('a');
      CheckEquals(0, ssl.IndexOf('a'), 'a 1');
      ssl.Add('b');
      CheckEquals(0, ssl.IndexOf('a'), 'a 2');
      CheckEquals(1, ssl.IndexOf('b'), 'b 2');
      Check(ssl.IndexOf('c')<0, 'c 3');
   finally
      ssl.Free;
   end;
end;

// ExceptionInInitialization
//
procedure TCornerCasesTests.ExceptionInInitialization;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'unit Dummy; interface implementation initialization'#13#10
                           +'Assert(False);'#13#10
                           +'finalization'#13#10
                           +'PrintLn("here");'#13#10
                           +'end.');

   CheckEquals('', prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('here'#13#10, exec.Result.ToString);
   CheckEquals('Runtime Error: Assertion failed [line: 2, column: 1]'#13#10, exec.Msgs.AsInfo);
end;

// ExceptionInFinalization
//
procedure TCornerCasesTests.ExceptionInFinalization;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'unit Dummy; interface implementation initialization finalization'#13#10
                           +'Assert(False);');

   CheckEquals('', prog.Msgs.AsInfo);

   exec:=prog.Execute;
   CheckEquals('Runtime Error: Assertion failed [line: 2, column: 1]'#13#10, exec.Msgs.AsInfo);
end;

// ErrorInInitialization
//
procedure TCornerCasesTests.ErrorInInitialization;
var
   prog : IdwsProgram;
   exec : IdwsExecution;
   code : String;
begin
   code := 'unit test; interface implementation'#10
         + 'var i := 0;'#10
         + 'initialization'#10
         + 'i := 1 div i;';
   prog := FCompiler.Compile(code);
   CheckEquals('', prog.Msgs.AsInfo, 'Compile');
   exec := prog.CreateNewExecution;
   try
      CheckFalse((exec as TdwsProgramExecution).BeginProgram, 'BeginProgram');
      Check(exec.ProgramState = psRunning, 'Running');
      CheckEquals('Runtime Error: Division by zero [line: 4, column: 8]'#13#10, exec.Msgs.AsInfo, 'Msgs');
   finally
      (exec as TdwsProgramExecution).EndProgram;
   end;
   exec := nil;
   prog := nil;
end;

// CaseOfBuiltinHelper
//
procedure TCornerCasesTests.CaseOfBuiltinHelper;
var
   prog : IdwsProgram;
begin
   FCompiler.Config.HintsLevel:=hlPedantic;

   prog:=FCompiler.Compile( 'var a : array of Integer;'#13#10
                           +'a.cleaR;');

   CheckEquals('Hint: "cleaR" does not match case of declaration ("Clear") [line: 2, column: 3]'#13#10, prog.Msgs.AsInfo, 'array');

(*
   TODO

   prog:=FCompiler.Compile( 'var s : String;'#13#10
                           +'s.lengtH;'#13#10
                           +'type TEnum = (One);'#13#10
                           +'s := One.Name;'#13#10
                           +'var se : set of TEnum;'#13#10
                           +'se.includE(one);'#13#10
                           );

   CheckEquals('bbb', prog.Msgs.AsInfo, 'string');

   prog:=FCompiler.Compile( 'type TEnum = (One);'#13#10
                           +'s := One.Name;'#13#10
                           +'var se : set of TEnum;'#13#10
                           +'se.includE(one);'#13#10
                           );

   CheckEquals('bbb', prog.Msgs.AsInfo, 'enums & sets');
*)
   FCompiler.Config.HintsLevel:=hlNormal;
end;

// CompilerInternals
//
procedure TCornerCasesTests.CompilerInternals;
var
   c : IdwsCompiler;
begin
   c:=FCompiler.Compiler;

   // this test is most meaningful when run after other tests

   CheckTrue(c.Msgs=nil, 'Msgs');
   CheckTrue(c.Tokenizer=nil, 'Tokenizer');
   CheckTrue(c.ExternalFunctionsManager=nil, 'External');
   CheckEquals(TdwsCompilerExecution.ClassName, c.CompileTimeExecution.ClassName, 'Exec');
end;

// CompilerAbort
//
procedure TCornerCasesTests.CompilerAbort;
var
   prog : IdwsProgram;
begin
   FCompiler.OnResource:=DoOnResource;

   prog:=FCompiler.Compile( 'var a := 1;'#13#10
                           +'{$R "abort"}'#13#10
                           +'bug bug bug');

   CheckEquals('Syntax Error: Compilation aborted [line: 3, column: 1]'#13#10, prog.Msgs.AsInfo, 'array');

   FCompiler.OnResource:=nil;
end;

// InitializationFinalization
//
procedure TCornerCasesTests.InitializationFinalization;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile( 'unit Test; '#13#10
                           +'interface'#13#10
                           +'implementation'#13#10
                           +'initialization'#13#10
                           +'Print("hello");'#13#10
                           +'finalization');

   CheckEquals('', prog.Msgs.AsInfo, 'no finalization compile');

   CheckEquals('hello', prog.Execute.Result.ToString, 'no finalization exec');
end;

// IsAbstractFlag
//
procedure TCornerCasesTests.IsAbstractFlag;
var
   prog : IdwsProgram;
   sym : TTypeSymbol;
begin
   prog:=FCompiler.Compile( 'type TA = class procedure A; virtual; abstract; end;'#13#10
                           +'type TS = class (TA) procedure A; override; begin end; end;');

   sym:=prog.Table.FindTypeSymbol('TA', cvMagic);
   Check(sym is TClassSymbol, 'TA class');
   Check(TClassSymbol(sym).IsAbstract, 'TA abstract');

   sym:=prog.Table.FindTypeSymbol('TS', cvMagic);
   Check(sym is TClassSymbol, 'TS class');
   Check(not TClassSymbol(sym).IsAbstract, 'TS not abstract');
end;

// InvalidAddUnit
//
procedure TCornerCasesTests.InvalidAddUnit;
var
   i : IdwsUnit;
   u : TdwsUnit;
   s : TDelphiWebScript;
begin
   u:=nil;
   try
      s:=TDelphiWebScript.Create(nil);
      try
         u:=TdwsUnit.Create(s);
         i:=u;
         s.AddUnit(u);
      finally
         s.Free;
      end;
   finally
      // recover the leak from the above exception (cf. TdwsAbstractUnit.BeforeAdditionTo)
      i:=nil;
      u.Free;
   end;
end;

// UnitOwnedByCompiler
//
procedure TCornerCasesTests.UnitOwnedByCompiler;
var
   u : TdwsUnit;
   s : TDelphiWebScript;
begin
   // owned but not used
   s:=TDelphiWebScript.Create(nil);
   try
      TdwsUnit.Create(s);
   finally
      s.Free;
   end;

   // owned and referred
   s:=TDelphiWebScript.Create(nil);
   try
      u:=TdwsUnit.Create(s);
      u.Script:=s;
   finally
      s.Free;
   end;

   CheckException(InvalidAddUnit, EdwsInvalidUnitAddition, 'TdwsUnit AddUnit');
end;

// BugInForVarConnectorExpr
//
procedure TCornerCasesTests.BugInForVarConnectorExpr;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile( 'var a : array of String;'#13#10
                           +'var j : JSONVariant;'#13#10
                           +'for var n in a do j[n] := ...');
   // no expected leak
   prog := nil;
end;

// MultiLineUnixStyle
//
procedure TCornerCasesTests.MultiLineUnixStyle;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog:=FCompiler.Compile( 'PrintLn(#'''#13#10
                           +'   hello'#13#10
                           +'   world'');');
   exec := prog.CreateNewExecution;
   exec.Execute(0);
   CheckEquals('hello'#13#10'world'#13#10, exec.Result.ToString, 'CRLF');

   prog:=FCompiler.Compile( 'PrintLn(#'''#10
                           +'   hello'#10
                           +'   world'');');
   exec := prog.CreateNewExecution;
   exec.Execute(0);
   CheckEquals('hello'#10'world'#13#10, exec.Result.ToString, 'LF');

end;

// EmptyProgram
//
procedure TCornerCasesTests.EmptyProgram;
var
   prog : IdwsProgram;
begin
   prog:=FCompiler.Compile('');
   CheckTrue(prog.IsEmpty, '""');
   prog:=FCompiler.Compile('// blabla'#13#10);
   CheckTrue(prog.IsEmpty, 'comments');
end;

// MessagesToJSON
//
procedure TCornerCasesTests.MessagesToJSON;
var
   wr : TdwsJSONWriter;
   prog : IdwsProgram;
begin
   wr := TdwsJSONWriter.Create(nil);
   try
      prog:=FCompiler.Compile('{$HINT "hello"}'#13#10'...');
      prog.Msgs.WriteJSONValue(wr);
      CheckEquals('[{"text":"hello","type":"Hint","pos":{"file":"*MainModule*","line":1,"col":3},"hintLevel":"Normal"},'
                 +'{"text":"Unexpected \"..\"","type":"SyntaxError","pos":{"file":"*MainModule*","line":2,"col":2}}]', wr.ToString);
   finally
      wr.Free;
   end;
end;

// MessagesEnumerator
//
procedure TCornerCasesTests.MessagesEnumerator;
var
   prog : IdwsProgram;
   n : Integer;
   msg : TdwsMessage;
begin
   prog := FCompiler.Compile('{$HINT "hello"}'#13#10'{$WARNING "world"}'#13#10'...');
   CheckEquals(3, prog.Msgs.Count, prog.Msgs.AsInfo);
   n := 0;
   for msg in prog.Msgs do begin
      case n of
         0 : CheckIs(msg, THintMessage);
         1 : CheckIs(msg, TWarningMessage);
         2 : CheckIs(msg, TSyntaxErrorMessage);
      end;
      Inc(n);
   end;
end;

// UnitNameTest
//
procedure TCornerCasesTests.UnitNameTest;
var
   prog : IdwsProgram;
begin
   prog := FCompiler.Compile('unit Hello;', 'World.pas');
   CheckEquals('Warning: Unit name does not match file name [line: 1, column: 6]'#13#10, prog.Msgs.AsInfo);

   prog := FCompiler.Compile('unit Hello.World;', 'Hello.World.pas');
   CheckEquals('', prog.Msgs.AsInfo);

   prog := FCompiler.Compile('unit Hello.World;', 'Hello.world.pas');
   CheckEquals('Hint: Unit name case does not match file name [line: 1, column: 6]'#13#10, prog.Msgs.AsInfo);

   prog := FCompiler.Compile('uses HelloWorld;');
   CheckEquals('', prog.Msgs.AsInfo);

   prog := FCompiler.Compile('uses Helloworld;');
   CheckEquals('Hint: Unit name case does not match file name [line: 1, column: 6]'#13#10, prog.Msgs.AsInfo);
end;

// ExceptionWithinMagic
//
procedure TCornerCasesTests.ExceptionWithinMagic;
var
   prog : IdwsProgram;
begin
   prog := FCompiler.Compile(
       'function Test : String; begin raise Exception.Create("hello"); end;'#13#10
     + 'PrintLn(Test);'
   );
   CheckEquals(  'Runtime Error: User defined exception: hello [line: 1, column: 62]'#13#10
               + ' [line: 2, column: 9]'#13#10,
               prog.Execute.Msgs.AsInfo);

   prog := FCompiler.Compile(
       'procedure Stuff; begin raise Exception.Create("world"); end;'#13#10
     + 'function Test : String; begin Stuff; end;'#13#10
     + 'PrintLn(Test);'
   );
   CheckEquals(  'Runtime Error: User defined exception: world [line: 1, column: 55]'#13#10
               + 'Test [line: 2, column: 31]'#13#10
               + ' [line: 3, column: 9]'#13#10,
               prog.Execute.Msgs.AsInfo);
end;

// DiscardEmptyElse
//
procedure TCornerCasesTests.DiscardEmptyElse;
var
   prog : IdwsProgram;
   e : TExprBase;
begin
   prog := FCompiler.Compile('procedure Test(a : Boolean); begin if a then Print(a) else ; end;');
   e := prog.Table.FindSymbol('Test', cvMagic).AsFuncSymbol.SubExpr[1];
   CheckEquals('TIfThenExpr', e.ClassName, 'empty else');

   prog := FCompiler.Compile('procedure Test(a : Boolean); begin if a then Print(a) else Print(a); end;');
   e := prog.Table.FindSymbol('Test', cvMagic).AsFuncSymbol.SubExpr[1];
   CheckEquals('TIfThenElseExpr', e.ClassName);

   prog := FCompiler.Compile('procedure Test(a : Boolean); begin if a then else Print(a); end;');
   e := prog.Table.FindSymbol('Test', cvMagic).AsFuncSymbol.SubExpr[1];
   CheckEquals('TIfThenExpr', e.ClassName, 'empty then');
end;

// AnonymousRecordWithConstArrayField
//
procedure TCornerCasesTests.AnonymousRecordWithConstArrayField;
var
   prog : IdwsProgram;
   code : String;
begin
   code := 'const cC : array [0..0] of record i : Integer end = [ ( i : 123 ) ];'#10
         + 'var b := record'#10
            + 'f := cC;'#10
         + 'end;';

   prog := FCompiler.Compile(code);
   CheckEquals(0, prog.Msgs.Count, 'first');
   prog := nil;
   prog := FCompiler.Compile(code);
   CheckEquals(0, prog.Msgs.Count, 'second');
   prog := nil;
end;

// Switch_TIMESTAMP
//
procedure TCornerCasesTests.Switch_TIMESTAMP;
var
   prog : IdwsProgram;
begin
   var ut1 := UnixTime;
   prog := FCompiler.Compile('Print({$include %TIMESTAMP%});');
   var ut2 := StrToIntDef(prog.Execute.Result.ToString, 0);
   prog := nil;

   var delta := ut2 - ut1;

   Check(delta in [0..1], 'Invalid TIMESTAMP delta ' + IntToStr(delta));
end;

// Switch_EXEVERSION
//
procedure TCornerCasesTests.Switch_EXEVERSION;
var
   prog : IdwsProgram;
begin
   prog := FCompiler.Compile('Print({$include %EXEVERSION%});');
   CheckEquals(ApplicationVersion, prog.Execute.Result.ToString, 'Invalid EXEVERSION');
   prog := nil;
end;

// UnderscoreNumbers
//
procedure TCornerCasesTests.UnderscoreNumbers;
var
   prog : IdwsProgram;
   code : String;
begin
   code := 'Print(1_);'#10
         + 'Print(1_2);'#10
         + 'Print(1_2_3);'#10
         + 'Print(4_.5);'#10
         + 'Print(4_5.6);'#10
         + 'Print(4_5_6.7);';

   prog := FCompiler.Compile(code);
   CheckEquals(0, prog.Msgs.Count, 'compile');

   CheckEquals('1121234.545.6456.7', prog.Execute.Result.ToString);
   prog := nil;
end;

// DelphiDialectProcedureTypes
//
procedure TCornerCasesTests.DelphiDialectProcedureTypes;
var
   opts : TCompilerOptions;
   prog : IdwsProgram;
begin
   opts := FCompiler.Config.CompilerOptions;
   try
      FCompiler.Config.HintsLevel := hlPedantic;

      FCompiler.Config.CompilerOptions := opts + [coDelphiDialect];
      prog := FCompiler.Compile( 'type TProc = reference to procedure;'#13#10
                                +'type TMethod = procedure of object;' );
      CheckEquals(0, prog.Msgs.Count, prog.Msgs.AsInfo);

      FCompiler.Config.CompilerOptions := opts - [coDelphiDialect];
      prog := FCompiler.Compile( 'type TProc = reference to procedure;'#13#10
                                +'type TMethod = procedure of object;' );
      CheckEquals(2, prog.Msgs.Count, prog.Msgs.AsInfo);

   finally
      FCompiler.Config.HintsLevel := hlNormal;
      FCompiler.Config.CompilerOptions := opts;
   end;
end;

// LambdaAsConstParam
//
procedure TCornerCasesTests.LambdaAsConstParam;
var
   prog : IdwsProgram;
begin
   FCompiler.Config.CompilerOptions := FCompiler.Config.CompilerOptions + [coAllowClosures];
   try
      prog := FCompiler.Compile(
         'type TSomeCallback = function (const a: TObject; const b: String; var c: Variant): Boolean;'#13#10
        +'procedure Test(const a: TObject; const b: String; var c: Variant; const callback: TSomeCallback);'#13#10
        +'begin callback(a, b, c); end;'#13#10
        +'var va : TObject;'#13#10
        +'var vb : String;'#13#10
        +'var vc : Variant;'#13#10
        +'Test(va, vb, vc, lambda => false);'
        );
      CheckEquals('', prog.Msgs.AsInfo);
   finally
      FCompiler.Config.CompilerOptions := FCompiler.Config.CompilerOptions - [coAllowClosures];
   end;
end;

// RoundTripTest
//
procedure TCornerCasesTests.RoundTripTest;
var
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
begin
   prog := FCompiler.Compile(
       'function Test(k : Integer) : String; begin'#13#10
        + 'if k <= 0 then exit "done";'#13#10
        + 'Print(k);'#13#10
        + 'Result := "," + RoundTrip("Test", k);'#13#10
     + 'end;'#13#10
     + 'PrintLn(Test(5));'
   );
   CheckEquals('', prog.Msgs.AsInfo);
   try
      exec := prog.CreateNewExecution;
      exec.Execute;
      CheckEquals('54321,,,,,done'#13#10, exec.Result.ToString);
   finally
      exec := nil;
   end;
end;

// ConstructorOverload
//
procedure TCornerCasesTests.ConstructorOverload;
var
   u : TdwsUnit;
   cls : TdwsClass;
   cst : TdwsConstructor;
   p : TdwsParameter;
   prog : IdwsProgram;
begin
   u := TdwsUnit.Create(nil);
   try
      u.UnitName := 'Test';

      cls := u.Classes.Add;
      cls.Name := 'TBase';

      cst := cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Attributes := [ maVirtual, maAbstract ];

      cls := u.Classes.Add;
      cls.Name := 'TDerived';
      cls.Ancestor := 'TBase';

      cst := cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Overloaded := True;
      cst.Attributes := [ maVirtual, maOverride ];

      cst := cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Overloaded := True;
      p := cst.Parameters.Add;
      p.Name := 'value';
      p.DataType := 'boolean';

      cls := u.Classes.Add;
      cls.Name := 'TProblem';
      cls.Ancestor := 'TDerived';

      cst := cls.Constructors.Add;
      cst.Name := 'Create';
      cst.Attributes := [ maVirtual, maOverride ];

      u.Script := FCompiler;

      prog := FCompiler.Compile('begin end;');
      try
         CheckEquals(0, prog.Msgs.Count, prog.Msgs.AsInfo);
      finally
         prog := nil;
      end;
   finally
      u.Free;
   end;
end;

// EndDot
//
procedure TCornerCasesTests.EndDot;
var
   prog : IdwsProgram;
begin
   prog := FCompiler.Compile(
        'unit Test; interface implementation'#10
      + 'initialization'#10
      + 'end'
   );
   CheckEquals('Warning: Dot "." expected [line: 3, column: 1]'#13#10, prog.Msgs.AsInfo);
   prog := FCompiler.Compile(
        'unit Test; interface implementation'#10
      + 'initialization'#10
      + 'finalization'#10
      + 'end'
   );
   CheckEquals('Warning: Dot "." expected [line: 4, column: 1]'#13#10, prog.Msgs.AsInfo);
end;

// SizeOfSpecial
//
procedure TCornerCasesTests.SizeOfSpecial;
var
   prog : IdwsProgram;
   code : String;
begin
   // SizeOf() is currently expressed in terms of variant slots
   // this is not set in stone, this test is more to keep track of that state of things

   code := 'Print(SizeOf(1));'#10
         + 'Print(SizeOf("hello"));'#10
         + 'var t : array [0..1] of Integer;'#10
         + 'Print(SizeOf(t));';
   prog := FCompiler.Compile(code);

   CheckEquals('112', prog.Execute.Result.ToString, 'SizeOf');
   prog := nil;
end;

// EmptyForLoop
//
procedure TCornerCasesTests.EmptyForLoop;
var
   prog : IdwsProgram;
begin
   prog := FCompiler.Compile('for var i := 1 to 10 do ;');
   CheckEquals('Hint: Empty FOR loop [line: 1, column: 25]'#13#10, prog.Msgs.AsInfo);
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   RegisterTest('CornerCasesTests', TCornerCasesTests);

end.
