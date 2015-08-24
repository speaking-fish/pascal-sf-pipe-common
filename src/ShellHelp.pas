{$undef USE_TPROCESS_FOR_WINDOWS}

{$include project.inc}

{$ifndef fpc}
  {$ifndef unix}
    {$define windows}
  {$endif}
{$endif}

//{$TYPEADDRESS ON}

{$ifdef fpc}
  {$ifdef unix}
    {$define USE_TPROCESS}
  {$else}
    {$ifdef USE_TPROCESS_FOR_WINDOWS}
      {$define USE_TPROCESS}
    {$endif}
  {$endif}
{$endif}
// Shell Helper

unit ShellHelp;

interface

uses
  {$ifdef unix}
    DynLibs, BaseUnix, Unix, //cthreads, unix,
  {$else}
    Windows,
  {$endif}
  Types, Classes,
  {$ifdef USE_TPROCESS}
    Process, syncobjs,
    //Pipes,
  {$endif}
  StrUtils,
  StreamUtil;

const EOL = {$ifndef unix} ^M^J {$else} '' + ^J {$endif};

const

  DEFAULT_PIPE_BUFFER_SIZE           = 1024;

type

  TSetOfChar = set of char;

  TProcessHelper = class
  public
    procedure terminate           ()         ; virtual; abstract;
    procedure resume              ()         ; virtual; abstract;
    function  terminated          (): boolean; virtual; abstract;
    function  hangs               (): boolean; virtual; abstract;
    function  isTerminated        (): boolean; virtual; abstract;
    function  isTerminating       (): boolean; virtual; abstract;
    function  processExitCode     (): dword  ; virtual; abstract;
    function  inputWriteStream    (): TStream; virtual; abstract;
    function  outputReadStream    (): TStream; virtual; abstract;
    function  errorReadStream     (): TStream; virtual; abstract;
    function  inputWritePipeHandle(): THandle; virtual; abstract;
    function  outputReadPipeHandle(): THandle; virtual; abstract;
    function  errorReadPipeHandle (): THandle; virtual; abstract;
  end;

  TCustomThread = class(TThread)
  protected
    _onExecute: TNotifyEvent;
    procedure execute; override;
  public
    constructor create(
      createSuspended: boolean;
      onExecute: TNotifyEvent
      );
    property onExecute: TNotifyEvent read _onExecute write _onExecute;
  end;

//  {$ifdef fpc}
//  TProcessRunner = class;
//  {$endif}

  TBooleanFunctionMethod = function(): boolean of object;

  TSimpleProcessHelper = class(TProcessHelper)
  protected
    _thread: TCustomThread;

    _commandName      : String       ;
    _commandParameters: String       ;
    _terminating      : boolean      ;
    _hangs            : TBooleanFunctionMethod;

    {$ifdef USE_TPROCESS}
      _process          : TProcess        ;
      _streamsReadyLock : TCriticalSection;
      _streamsReady     : boolean         ;
    //_streamsReadyEvent: TEvent          ;
    //_processRunner    : TProcessRunner;
      _execError        : boolean;
      _execErrorType    : String;
      _execErrorMessage : String;
      procedure fireStreamsReady();
      procedure waitStreamsReady();
    {$else}
      _process          : THandle      ;

      _processExitCode  : dword        ;

      _inputReadPipe    : THandle      ;
      _inputWritePipe   : THandle      ;
      _outputReadPipe   : THandle      ;
      _outputWritePipe  : THandle      ;
      _errorReadPipe    : THandle      ;
      _errorWritePipe   : THandle      ;

      _inputWriteStream : TNormalHandleStream;
      _outputReadStream : TNormalHandleStream;
      _errorReadStream  : TNormalHandleStream;
    {$endif}
    procedure doExecute(sender: TObject);
    procedure execute; //override;
  public
    constructor create(
      const commandName      : String         ;
      const commandParameters: String         ;
            passthroughError : boolean = false;
            hangs_           : TBooleanFunctionMethod = nil
      );
    destructor destroy; override;

    procedure terminate           ()         ; override;
    procedure resume              ()         ; override;
    function  terminated          (): boolean; override;
    function  hangs               (): boolean; override;
    function  isTerminated        (): boolean; override;
    function  isTerminating       (): boolean; override;
    function  processExitCode     (): dword  ; override;
    function  inputWriteStream    (): TStream; override;
    function  outputReadStream    (): TStream; override;
    function  errorReadStream     (): TStream; override;
    function  inputWritePipeHandle(): THandle; override;
    function  outputReadPipeHandle(): THandle; override;
    function  errorReadPipeHandle (): THandle; override;

  end;

  //{$ifdef fpc}
  //TProcessRunner = class(TThread)
  //protected
  //  _helper: TProcessHelper;
  //  procedure execute; override;
  //public
  //  constructor create(helper_: TProcessHelper);
  //  destructor destroy; override;
  //end;
  //{$endif}

  TWatchdogProcessHelper = class(TProcessHelper)
  protected
    _helper              : TSimpleProcessHelper  ;
    _output              : TLockBufferHelper     ;
    {
    _outputReader        : TStreamGobbler        ;
    _outputReaderWatchdog: TStreamGobblerWatchdog;
    _error               : TLockBufferHelper     ;
    _errorReader         : TStreamGobbler        ;
    }
    _inputWriteStream    : TCustomDelegateStream ;
    _outputReader        : TStreamCopier         ;
    _outputReaderWatchdog: TStreamCopierWatchdog ;
    _error               : TLockBufferHelper     ;
    _errorReader         : TStreamCopier         ;
    {
    _errorReaderWatchdog : TStreamGobblerWatchdog;
    }
    procedure inputWriteStream_flush(sender: TObject);
  public
    constructor create(
      const commandName      : String         ;
      const commandParameters: String         ;
            capacity         : integer        ;
            waitForDataMs    : longint        ;
            waitToKillMs     : longint        ;
      const passthroughError : boolean = false
      );
    destructor destroy; override;

    procedure terminate           ()         ; override;
    procedure resume              ()         ; override;
    function  terminated          (): boolean; override;
    function  hangs               (): boolean; override;
    function  isTerminated        (): boolean; override;
    function  isTerminating       (): boolean; override;
    function  processExitCode     (): dword  ; override;
    function  inputWriteStream    (): TStream; override;
    function  outputReadStream    (): TStream; override;
    function  errorReadStream     (): TStream; override;
    function  inputWritePipeHandle(): THandle; override;
    function  outputReadPipeHandle(): THandle; override;
    function  errorReadPipeHandle (): THandle; override;

    procedure enableOutputReaderWatchdog(enable: boolean);
  end;

procedure appendTo(var dest: TStringDynArray; const value: String); overload;

function paramStrs(first, last: integer): String;

function quoteSpaces(const src: String): String;

function extractFileNameOnly(const fullName: String): String;

{$ifdef windows}
function searchFile(const fileName: String; const extension: String): String; overload;
function searchFile(const fileName: String; const extensions: array of string): String; overload;
{$endif}

function quoteParamStr(const value: String): String;

function filenameContainsPath(const fileName: String): boolean;

implementation

uses
  SysUtils{,

  Misc};

{
function handleGetCommTimeouts(handle: THandle): COMMTIMEOUTS;
  begin
    if not getCommTimeouts(handle, result) then
      raise Exception.create('Error create input pipe: ' + sysErrorMessage(getLastError()));
  end;

procedure handleSetCommTimeouts(handle: THandle; const params: COMMTIMEOUTS);
  begin
    if not setCommTimeouts(handle, params)then
      raise Exception.create('Error create input pipe: ' + sysErrorMessage(getLastError()));
  end;
}

procedure appendTo(var dest: TStringDynArray; const value: String); overload;
  var oldLength: integer;
  begin
    oldLength:= length(dest);
    setLength(dest, oldLength + 1);
    dest[oldLength]:= value;
  end;

function split(const values: String; const chars: TSetOfChar): TStringDynArray;
  var
    anchor: integer;
    ch    : char;
    i     : integer;
  begin
    setLength(result, 0);

    anchor:= 1;
    for i:= 1 to length(values) do
      begin
        ch:= values[i];
        if ch in chars then
          begin
            if anchor < i then
              appendTo(result, copy(values, anchor, i - anchor));
            anchor:= i + 1;
            if i = length(values) then
              exit;
          end;
      end;

    appendTo(result, copy(values, anchor, length(values) + 1 - anchor));
 end;

function join(delimiter: String; const values: TStringDynArray): String; overload;
  var i: integer;
  begin
    result:= '';
    if 0 < length(values) then
      begin
        result:= values[low(values)];
        for i:= low(values) + 1 to high(values) do
          result:= result + delimiter + values[i];
      end;
  end;

function normalizePath(const src: TStringDynArray): TStringDynArray; overload;
  var i: integer;
  var s: String;
  begin
    setLength(result, 0);
    for i:= 0 to length(src) - 1 do
      begin
        s:= src[i];
        if not ansiSameStr('.', s) then
          begin
            if '..' = s then
              begin
                if 0 = length(result) then
                  appendTo(result, s)
                else if '..' = result[length(result) - 1] then
                  appendTo(result, s)
                else
                  setLength(result, length(result) - 1);
              end
            else
              appendTo(result, s);
          end;
      end;
  end;

function normalizePath(const src: String): String; overload;
  begin
    result:= join({$ifdef unix} '/' {$else} '\' {$endif}, normalizePath(split(src, ['/','\'])));
    if true
      and (0 < length(src))
      and (false
        or (0 = length(result))
        or ((src[1] in ['/','\']) and not (result[1] in ['/','\']))
        )
    then
      result:= {$ifdef unix} '/' {$else} '\' {$endif} + result;
  end;


function normalizeFullname(const src: String): String; overload;
  var temp: TStringDynArray;
  var fileName: String;
  begin
    result:= src;
    if 0 = length(src) then
      exit;

    if src[length(src)] in ['/','\'] then
      begin
        result:= normalizePath(src);
        exit;
      end;

    temp:= split(src, ['/','\']);
    if 0 < length(temp) then
      begin
        fileName:= temp[length(temp) - 1];
        setLength(temp, length(temp) - 1);
        temp:= normalizePath(temp);
        appendTo(temp, fileName);
        result:= join({$ifdef unix} '/' {$else} '\' {$endif}, temp);
      end;
    if true
      and (0 < length(src))
      and (false
        or (0 = length(result))
        or ((src[1] in ['/','\']) and not (result[1] in ['/','\']))
        )
    then
      result:= {$ifdef unix} '/' {$else} '\' {$endif} + result;
  end;

function isAbsolutePathname(const value: String): boolean;
  begin
    result:= (0 <> length(value))
      and ((value[1] = '/') or (value[1] = '\') {$ifndef unix} or ((2 <= length(value)) and (':' = value[2])) {$endif});
  end;

function addPathDelimter(const value: String): String;
  begin
    if (0 = length(value)) or not (('/' = value[length(value)]) or ('\' = value[length(value)])) then
      result:= value + {$ifdef unix} '/' {$else} '\' {$endif} else
      result:= value;
  end;

function makeAbsolutePathname(const value: String; const relativeTo: String): String; overload;
  begin
    if isAbsolutePathname(value) then
      result:= value else
      result:= addPathDelimter(relativeTo) + value;
  end;

function makeAbsolutePathname(const value: String): String; overload;
  begin
    result:= makeAbsolutePathname(value, getCurrentDir());
  end;

constructor TCustomThread.create(
  createSuspended: boolean     ;
  onExecute      : TNotifyEvent
  );
  begin
    _onExecute:= onExecute;
    inherited create(createSuspended);
  end;

procedure TCustomThread.execute;
  begin
    if assigned(onExecute) then
      onExecute(self);
  end;

constructor TSimpleProcessHelper.create(
  const commandName      : String         ;
  const commandParameters: String         ;
        passthroughError : boolean = false;
        hangs_           : TBooleanFunctionMethod = nil
  );
  {$ifdef USE_TPROCESS}
  {$else}
  var
    startupInfo: TStartupInfo;
    processInformation: TProcessInformation;
    bResult: Boolean;
    timeouts: COMMTIMEOUTS;
    {
    HWnd: THandle;
    ErrorCode: DWord;
    ErrorStr: String;
    ProgramFileName, Params: String;
    WaitResult: TWaitHandlesResult;
    WaitIndex: Integer;
    SaveProgramFileName: String;
    }
    commandFullName: String;
  {$endif}
  begin
    //inherited create(true);
    inherited create();
    _hangs:= hangs_;
    _thread:= TCustomThread.create(true, doExecute);

    _commandName      := commandName      ;
    _commandParameters:= commandParameters;
    //writeLn(StdErr, 'Running ' + commandName + ' ' + commandParameters);
    try
      {$ifdef USE_TPROCESS}
        _streamsReadyLock:= TCriticalSection.create();
        _process:= TProcess.create(nil);
        _process.options:= [poUsePipes, poDebugProcess];
        if passthroughError then
          _process.options:= _process.options + [poStderrToOutPut{, poWaitOnExit}];
        _process.commandLine:= quoteParamStr({normalizeFullname}({makeAbsolutePathname ExpandFileName}(commandName))) + ' ' + commandParameters;
        //_process.active:= true;
        //_process.execute();
      {$else}
        if not createPipe(
          _inputReadPipe,
          _inputWritePipe,
          nil, //_In_opt_  LPSECURITY_ATTRIBUTES lpPipeAttributes,
          DEFAULT_PIPE_BUFFER_SIZE * 10//0
          )
        then
          raise Exception.create('Error create input pipe: ' + sysErrorMessage(getLastError()));

        if not createPipe(
          _outputReadPipe,
          _outputWritePipe,
          nil, //_In_opt_  LPSECURITY_ATTRIBUTES lpPipeAttributes,
          DEFAULT_PIPE_BUFFER_SIZE * 10//0
          )
        then
          raise Exception.create('Error create output pipe: ' + sysErrorMessage(getLastError()));

        if not passthroughError then
          if not createPipe(
            _errorReadPipe,
            _errorWritePipe,
            nil, //_In_opt_  LPSECURITY_ATTRIBUTES lpPipeAttributes,
            DEFAULT_PIPE_BUFFER_SIZE//0
            )
          then
            raise Exception.create('Error create error pipe: ' + sysErrorMessage(getLastError()));
  {
        timeouts:= handleGetCommTimeouts(_inputReadPipe  );
        timeouts:= handleGetCommTimeouts(_inputWritePipe );
        timeouts:= handleGetCommTimeouts(_outputReadPipe );
        timeouts:= handleGetCommTimeouts(_outputWritePipe);
        timeouts:= handleGetCommTimeouts(_errorReadPipe  );
        timeouts:= handleGetCommTimeouts(_errorWritePipe );
  }
        _inputWriteStream:= TNormalHandleStream.create(_inputWritePipe);
        _outputReadStream:= TNormalHandleStream.create(_outputReadPipe);
        if not passthroughError then
          _errorReadStream := TNormalHandleStream.create(_errorReadPipe  );

        (*
        FillChar(ShellExecuteInfo, SizeOf(ShellExecuteInfo), 0);
        with ShellExecuteInfo do
          begin
            cbSize      := SizeOf(ShellExecuteInfo); // DWORD
            fMask       := SEE_MASK_NOCLOSEPROCESS; // ULONG
            Wnd         := Application.Handle; // HWND
            lpVerb      := nil; // PAnsiChar
            lpFile      := PChar(FCommandLine); // PAnsiChar
            lpParameters:= nil; //PAnsiChar
            lpDirectory := nil; // PAnsiChar
            nShow       := SW_SHOWDEFAULT; // SQ_HIDE; // Integer
            // return hInstApp    : HINST
            { Optional fields }
            lpIDList    := nil; // Pointer
            lpClass     := nil; // PAnsiChar
            hkeyClass   := 0; // HKEY
            dwHotKey    := 0; // DWORD
            hIcon       := 0; // THandle
            // retutn hProcess    : THandle
          end;
        if not ShellExecuteEx(@ShellExecuteInfo) then
          Exit;

        if ShellExecuteInfo.hProcess = 0 then
          Exit;

        FProcessID:= ShellExecuteInfo.hProcess;
        *)
    {
    As a workaround, use AllocConsole(), then the following method:

    1. Use SetStdHandle() to set the desired handles to be inherited.

       -or-

       Use DuplicateHandle() to change the inheritance property of handles
       that should not be inherited.
    }

        //StartTimer('starting process');
        fillChar(startupInfo, sizeOf(startupInfo), 0);
        startupInfo.cb             := sizeOf(startupInfo); // DWORD;
        //lpReserved     : Pointer;
        //lpDesktop      : Pointer;
        //lpTitle        : Pointer;
        //dwX            : DWORD;
        //dwY            : DWORD;
        //dwXSize        : DWORD;
        //dwYSize        : DWORD;
        //dwXCountChars  : DWORD;
        //dwYCountChars  : DWORD;
        //dwFillAttribute: DWORD;
        {
        if not NoOverlapIO then
        }
          startupInfo.dwFlags        := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW; // DWORD;
        startupInfo.wShowWindow      := {SW_SHOWNORMAL;} SW_HIDE;
        //cbReserved2    : Word;
        //lpReserved2    : PByte;
        {
        if not NoOverlapIO then
          begin
        }
            (*
            {
            if FInputFileName <> '' then
              begin
            }
                BResult:= SetHandleInformation(
                  FInputStream.Handle, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT
                  );

                hStdInput  := FInputStream.Handle;
            {
              end;
            }
            hStdOutput     := FTempOutputStream.Handle; //THandle;
            hStdError      := FTempErrorStream.Handle; //THandle;
            *)

            startupInfo.hStdInput := _inputReadPipe  ;
            startupInfo.hStdOutput:= _outputWritePipe;
            if passthroughError then
              startupInfo.hStdError := GetStdHandle(STD_OUTPUT_HANDLE)
            else
              startupInfo.hStdError := _errorWritePipe ;
          {
          end;
          }
        bResult:= setHandleInformation(_inputReadPipe  , HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
        bResult:= setHandleInformation(_outputWritePipe, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
        if not passthroughError then
          bResult:= setHandleInformation(_errorWritePipe , HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);

        try
          if filenameContainsPath(_commandName) then
            begin
              if fileExists(_commandName + '.exe') then
                commandFullName:= _commandName + '.exe'
              else if fileExists(_commandName + '.cmd') then
                commandFullName:= _commandName + '.cmd'
              else if fileExists(_commandName + '.bat') then
                commandFullName:= _commandName + '.bat'
              else if fileExists(_commandName) then
                commandFullName:= _commandName
              else
                commandFullName:= _commandName;
            end
          else
            begin
              commandFullName:= searchFile(_commandName, ['.cmd', '.bat', '.exe']);
              if 0 = length(commandFullName) then
                commandFullName:= _commandName;
            end;
        except on e: Exception do
          raise Exception.create('Error resolve executable name "' + _commandName + '" : ' + e.message);
        end;

        if not createProcess(
          nil,
          pchar(quoteSpaces(commandFullName) + ' ' + _commandParameters),
          nil,
          nil,
          true, // inherit handles
          NORMAL_PRIORITY_CLASS, // or CREATE_NEW_PROCESS_GROUP, //IDLE_PRIORITY_CLASS, //CREATE_NEW_PROCESS_GROUP, // 0, //IDLE_PRIORITY_CLASS, //	0, //CREATE_NEW_CONSOLE,
          nil,
          nil,
          startupInfo,
          processInformation
          )
        then
          raise Exception.create('ShellHelper.createProcess error: ' + sysErrorMessage(getLastError()));

        _process:= processInformation.hProcess;
      {$endif}
    except
      on e: Exception do
        begin
          {$ifdef USE_TPROCESS}
            _process.free();
            _process:= nil;
          {$else}
            closeHandle(_inputReadPipe  );
            closeHandle(_inputWritePipe );
            {
            cancelIo   (_outputReadPipe , nil);
            cancelIo   (_outputWritePipe, nil);
            }
            closeHandle(_outputReadPipe );
            closeHandle(_outputWritePipe);
            {
            cancelIo   (_errorReadPipe  );
            cancelIo   (_errorWritePipe );
            }
            if not passthroughError then
              begin
                closeHandle(_errorReadPipe  );
                closeHandle(_errorWritePipe );
              end;

            _inputWriteStream.free();
            _inputWriteStream:= nil;

            _outputReadStream.free();
            _outputReadStream:= nil;

            _errorReadStream.free();
            _errorReadStream:= nil;
            raise;
            {$endif}
        end;
    end;
  end;

destructor TSimpleProcessHelper.destroy;
  begin
    terminate();
    
    _thread.free();
    _thread:= nil;

    inherited;

    {$ifdef USE_TPROCESS}

      _process.free();
      _process:= nil;

      _streamsReadyLock.free();
      _streamsReadyLock:= nil;

    {$else}

      closeHandle(_process);

      cancelIo   (_inputReadPipe  );
      cancelIo   (_inputWritePipe );

      closeHandle(_inputReadPipe  );
      closeHandle(_inputWritePipe );

      cancelIo   (_outputReadPipe );
      cancelIo   (_outputWritePipe);

      closeHandle(_outputReadPipe );
      closeHandle(_outputWritePipe);

      cancelIo   (_errorReadPipe  );
      cancelIo   (_errorWritePipe );

      closeHandle(_errorReadPipe  );
      closeHandle(_errorWritePipe );

      _inputWriteStream.free();
      _inputWriteStream:= nil;

      _outputReadStream.free();
      _outputReadStream:= nil;

      _errorReadStream.free();
      _errorReadStream:= nil;

    {$endif}
  end;

{$ifdef USE_TPROCESS}

procedure TSimpleProcessHelper.fireStreamsReady();
  begin
    _streamsReadyLock.enter();
    try
      _streamsReady:= true;
    finally
      _streamsReadyLock.leave();
    end;
  end;

procedure TSimpleProcessHelper.waitStreamsReady();
  begin
    while true do
      begin
        _streamsReadyLock.enter();
        try
          if _streamsReady then
            break;
        finally
          _streamsReadyLock.leave();
        end;
        sleep(100);
      end;
  end;

{$endif}

procedure TSimpleProcessHelper.terminate;
  begin
    if not isTerminated() and not isTerminating() then
      begin
        _terminating:= true;
        {$ifdef USE_TPROCESS}
          _process.terminate(0);
        {$else}
          terminateProcess(_process, 0);
        {$endif}
      end;
  end;

function TSimpleProcessHelper.isTerminated(): boolean;
  begin
    result:= true;
    {$ifdef USE_TPROCESS}
      if _execError then
        exit;

      if not assigned(_process) then
        exit;

      result:= not _process.active;
    {$else}
      if (0 = _process) or (_process = INVALID_HANDLE_VALUE) then
        exit;

      if getExitCodeProcess(_process, _processExitCode) then
        result:= STILL_ACTIVE <> _processExitCode;
    {$endif}
  end;

function TSimpleProcessHelper.isTerminating(): boolean;
  begin result:= _terminating; end;

function TSimpleProcessHelper.processExitCode : dword  ;
  begin
    {$ifdef USE_TPROCESS}
      result:= _process.exitStatus;
    {$else}
      result:= _processExitCode ;
    {$endif}
  end;

function TSimpleProcessHelper.inputWriteStream: TStream;
begin
  {$ifdef USE_TPROCESS}
    waitStreamsReady();
    result:= _process.input;
  {$else}
    result:= _inputWriteStream;
  {$endif}
end;

function TSimpleProcessHelper.outputReadStream: TStream;
begin
  {$ifdef USE_TPROCESS}
    waitStreamsReady();
    result:= _process.output;
  {$else}
    result:= _outputReadStream;
  {$endif}
end;

function TSimpleProcessHelper.errorReadStream : TStream;
begin
  {$ifdef USE_TPROCESS}
    waitStreamsReady();
    result:= _process.stderr;
  {$else}
    result:= _errorReadStream ;
  {$endif}
end;


function TSimpleProcessHelper.hangs(): boolean;
  begin
    result:= false;
    if assigned(_hangs) then
      result:= _hangs;
    {
    InterlockedExchange();
    result:= __checkCount
    }
  end;

procedure TSimpleProcessHelper.resume   ();
                                                    begin _thread.resume   (); end;
function TSimpleProcessHelper.terminated(): boolean;
                                                    begin result:= _thread.terminated; end;

function  TSimpleProcessHelper.inputWritePipeHandle(): THandle;
   begin
     {$ifdef USE_TPROCESS}
       result:= _process.input.handle;
     {$else}
       result:= _inputWriteStream.handle;
     {$endif}
   end;

function  TSimpleProcessHelper.outputReadPipeHandle(): THandle;
  begin
    {$ifdef USE_TPROCESS}
      result:= _process.output.handle;
    {$else}
      result:= _outputReadStream.handle;
    {$endif}
  end;

function  TSimpleProcessHelper.errorReadPipeHandle (): THandle;
  begin
    {$ifdef USE_TPROCESS}
      result:= _process.stderr.handle;
    {$else}
      result:= _errorReadStream .handle;
    {$endif}
  end;

procedure TSimpleProcessHelper.doExecute(sender: TObject);
  begin
    execute;
  end;

procedure TSimpleProcessHelper.execute;
  {$ifdef USE_TPROCESS}
  var waitResult: boolean;
  {$endif}
  begin
    {$ifdef USE_TPROCESS}
      try
        try
          _process.execute();
        except on e: Exception do
          begin
            _execError:= true;
            _execErrorType:= e.className;
            _execErrorMessage:= e.message;
          end;
        end;
      finally
        fireStreamsReady();
      end;
      try
        while not Terminated and not isTerminated do
          begin
            sleep(500);
            if hangs() then
              terminate();
          end;
      finally
        waitResult:= _process.waitOnExit;
      end;
    {$else}
      while not terminated and not isTerminated do
        begin
          sleep(500);
          if hangs() then
            terminate();
        end;
    {$endif}

    (*
    //StopTimer('starting process');

    repeat
      //StartTimer('process cycle');
      if not getExitCodeProcess(_process, _processExitCode) then
        Break;
      if _processExitCode <> STILL_ACTIVE then
        Break;
      //Sleep(0);

      if not NoOverlapIO then
        WaitResult:= WaitHandles(
          [Handle, FProcess, FTempOutputStream.Handle, FTempErrorStream.Handle],
          False,
          INFINITE,
          WaitIndex
          )
      else
        WaitResult:= WaitHandles(
          [Handle, FProcess],
          False,
          INFINITE,
          WaitIndex
          );

    until False;
    *)
  end;

//{$ifdef fpc}
//constructor TProcessRunner.create(helper_: TProcessHelper);
//  begin
//    _helper:= helper;
//    inherited create(false);
//  end;
//
//destructor TProcessRunner.destroy; override;
//  begin
//    inherited destory;
//    _helper:= nil;
//  end;
//
//procedure TProcessRunner.execute; override;
//  begin
//    _helper.execute();
//  end;
//{$endif}

constructor TWatchdogProcessHelper.create(
  const commandName      : String         ;
  const commandParameters: String         ;
        capacity         : integer        ;
        waitForDataMs    : longint        ;
        waitToKillMs     : longint        ;
  const passthroughError : boolean = false
  );
  begin
    inherited create();
    _helper              := TSimpleProcessHelper  .create(commandName                 ,
                                                          commandParameters           ,
                                                          passthroughError            ,
                                                          hangs                       );

    _inputWriteStream    := TCustomDelegateStream .create(_helper.inputWriteStream    );
    _inputWriteStream.onFlush:= self.inputWriteStream_flush;

    _output              := TLockBufferHelper     .create(capacity                    ,
                                                          waitForDataMs               );
    {
    _outputReader        := TStreamGobbler        .create(_helper.outputReadPipeHandle,
    _output                                                      .output              ,
                                                          true                        );
    _outputReaderWatchdog:= TStreamGobblerWatchdog.create(
    _outputReader                                                                     ,
                                                          waitToKillMs                ,
                                                          true                        );
    }
    _outputReader        := TStreamCopier         .create(false                       , _helper
    .outputReadStream                                                                 ,
                                                          false                       ,
    _output                                                      .output              ,
    'WatchdogProcessHelper.outputReader: ' + commandName + ' ' + commandParameters    );

    _outputReaderWatchdog:= TStreamCopierWatchdog .create(
    _outputReader                                                                     ,
                                                          waitToKillMs                ,
                                                          true                        );

    if passthroughError then exit;

    _error               := TLockBufferHelper     .create(capacity                    ,
                                                          waitForDataMs               );
    {
    _errorReader         := TStreamGobbler        .create(_helper.errorReadPipeHandle ,
    _error                                                       .output              ,
                                                          true                        );
    }
    _errorReader         := TStreamCopier         .create(false                       , _helper
    .errorReadStream                                                                  ,
                                                          false                       ,
    _error                                                       .output              ,
    'WatchdogProcessHelper.errorReader: ' + commandName + ' ' + commandParameters     );
    {
    _errorReaderWatchdog := TStreamGobblerWatchdog.create(
    _errorReader                                                                      ,
                                                          waitToKillMs                ,
                                                          true                        );
    }
  end;

destructor TWatchdogProcessHelper.destroy;
  begin
    {
    _errorReaderWatchdog .free();
    _errorReaderWatchdog := nil;
    }

    _errorReader         .free();
    _errorReader         := nil;

    _error               .free();
    _error               := nil;

    _outputReaderWatchdog.free();
    _outputReaderWatchdog:= nil;

    _outputReader        .free();
    _outputReader        := nil;

    _output              .free();
    _output              := nil;

    _inputWriteStream    .free();
    _inputWriteStream    := nil;

    _helper              .free();
    _helper              := nil;

    inherited destroy();
  end;

procedure TWatchdogProcessHelper.inputWriteStream_flush(sender: TObject);
  begin
    enableOutputReaderWatchdog(true);
    tryFlushStream(_inputWriteStream.origin);
  end;

procedure TWatchdogProcessHelper.terminate       ()         ;
  begin
    _helper              .terminate();
    _outputReaderWatchdog.terminate();
    _outputReader        .terminate();

    if assigned(_errorReader) then
    _errorReader         .terminate();
    {
    _errorReaderWatchdog .terminate();
    }
  end;

procedure TWatchdogProcessHelper.resume          ()         ;
  begin
    _helper              .resume();
    _outputReader        .resume();
    _outputReaderWatchdog.resume();
    if assigned(_errorReader) then
    _errorReader         .resume();
    {
    _errorReaderWatchdog .resume();
    }
  end;

function  TWatchdogProcessHelper.terminated          (): boolean;
                                                                  begin result:= _helper.terminated          (); end;
function  TWatchdogProcessHelper.hangs               (): boolean;
                                                                  begin result:= _outputReader.isTerminated  (); end;

function  TWatchdogProcessHelper.isTerminated        (): boolean;
                                                                  begin result:= _helper.isTerminated        (); end;
function  TWatchdogProcessHelper.isTerminating       (): boolean;
                                                                  begin result:= _helper.isTerminating       (); end;
function  TWatchdogProcessHelper.processExitCode     (): dword  ;
                                                                  begin result:= _helper.processExitCode     (); end;
function  TWatchdogProcessHelper.inputWriteStream    (): TStream;
                                                                  begin result:= _inputWriteStream             ; end;
function  TWatchdogProcessHelper.outputReadStream    (): TStream;
                                                                  begin result:= _output.input                 ; end;
function  TWatchdogProcessHelper.inputWritePipeHandle(): THandle;
                                                                  begin result:= _helper.inputWritePipeHandle(); end;
function  TWatchdogProcessHelper.outputReadPipeHandle(): THandle;
                                                                  begin result:= _helper.outputReadPipeHandle(); end;
function  TWatchdogProcessHelper.errorReadPipeHandle (): THandle;
                                                                  begin result:= _helper.errorReadPipeHandle (); end;

function  TWatchdogProcessHelper.errorReadStream     (): TStream;
  begin
    if assigned(_error) then
      result:= _error .input else
      result:= nil;
  end;

procedure TWatchdogProcessHelper.enableOutputReaderWatchdog(enable: boolean);
  begin
    {
    if enable then
      begin
        _lastEnableWatchdogTick:= getTickCount()
        //_watchdogEnable:= true;
        _outputReaderWatchdog.setEnabled(true);
      end
    else
      begin
        //_watchdogEnable:= false;
        _outputReaderWatchdog.setEnabled(false);
      end
    }  
    _outputReaderWatchdog.setEnabled(enable);
  end;

function paramStrs(first, last: integer): String;
  var i: integer;
  begin
    result:= paramStr(first);
    for i:= first + 1 to last do
      result:= result + ' ' + quoteSpaces(paramStr(i));
  end;

function quoteSpaces(const src: String): String;
  begin
    if 0 < pos(' ', src) then
      result:= '"' + src + '"' else
      result:= src;
  end;

function extractFileNameOnly(const fullName: String): String;
  begin
    result:= changeFileExt(extractFileName(fullName), '');
  end;

{$ifdef windows}

//{$ifdef fpc}
  //{$ifdef windows}
    // fix invalid header in fpc: lost 'var' (like in delphi)
    // variant: use LPPCSTR instead of lpFilePart:LPSTR and add {$ifdef fpc} @ {$endif} when call
    //function SearchPath(lpPath:LPCSTR; lpFileName:LPCSTR; lpExtension:LPCSTR; nBufferLength:DWORD; lpBuffer:LPSTR;var lpFilePart:LPSTR):DWORD; external 'kernel32' name 'SearchPathA';
    //function SearchPath(lpPath:LPCSTR; lpFileName:LPCSTR; lpExtension:LPCSTR; nBufferLength:DWORD; lpBuffer:LPSTR; lpFilePart: LPPCSTR):DWORD; external 'kernel32' name 'SearchPathA';
  //{$endif}
//{$endif}

function searchFile(const fileName: String; const extension: String): String; overload;
  var
    pExtension       : pchar;
    lastValidFilePart: pchar;
    size             : dword;

  var buffer: array[0..512] of char;

  begin
    // FPC has invalid header : lost 'var' (like in delphi)
    // fpc: function SearchPath(lpPath:LPCSTR; lpFileName:LPCSTR; lpExtension:LPCSTR; nBufferLength:DWORD; lpBuffer:LPSTR;
    // >>> lpFilePart:LPSTR):DWORD; external 'kernel32' name 'SearchPathA';
    // delphi: function SearchPath(lpPath, lpFileName, lpExtension: PChar; nBufferLength: DWORD; lpBuffer: PChar;
    // >>> var lpFilePart: PChar): DWORD; stdcall;

    pointer(lastValidFilePart):= @lastValidFilePart; // trick! point to itself to avoid var pointer / non-var ppointer differences

    fillchar(buffer[0], sizeof(buffer), 0); //' '); // 0 to bug reproduce
    buffer[sizeof(buffer) - 1]:= #0;

    if extension <> '' then
      pExtension:= pchar(extension) else
      pExtension:= nil;

    result:= makeAnsiString(@buffer, 0, searchPath(
      nil,
      @(filename[1]),
      pExtension       ,
      sizeof(buffer)   ,
      buffer           ,
      lastValidFilePart
      ));

  end;

function searchFile(const fileName: String; const extensions: array of string): String; overload;
  var i: integer;
  begin
    result:= '';
    for i:= low(extensions) to high(extensions) do
      begin
        result:= searchFile(fileName, extensions[I]);
        if result <> '' then
          break;
      end;
  end;

{$endif}

// fix invalid binaries (possible bad optimization) in some versions of fpc
// this is identical copy from fpc source

Function StringReplace(const S, OldPattern, NewPattern: string;  Flags: TReplaceFlags): string;
var
  Srch,OldP,RemS: string; // Srch and Oldp can contain uppercase versions of S,OldPattern
  P : Integer;
begin
  Srch:=S;
  OldP:=OldPattern;
  if rfIgnoreCase in Flags then
    begin
    Srch:=AnsiUpperCase(Srch);
    OldP:=AnsiUpperCase(OldP);
    end;
  RemS:=S;
  Result:='';
  while (Length(Srch)<>0) do
    begin
    P:=AnsiPos(OldP, Srch);
    if P=0 then
      begin
      Result:=Result+RemS;
      Srch:='';
      end
    else
      begin
      Result:=Result+Copy(RemS,1,P-1)+NewPattern;
      P:=P+Length(OldP);
      RemS:=Copy(RemS,P,Length(RemS)-P+1);
      if not (rfReplaceAll in Flags) then
        begin
        Result:=Result+RemS;
        Srch:='';
        end
      else
         Srch:=Copy(Srch,P,Length(Srch)-P+1);
      end;
    end;
end;

Function AnsiReplaceStr(const AText, AFromText, AToText: string): string;
begin
Result := StringReplace(AText,AFromText,AToText,[rfReplaceAll]);
end;

function quoteParamStr(const value: String): String;
  begin
    if 0 = length(value) then
      result:= ''
    else if (2 <= length(value)) and ('"' = value[1]) and ('"' = value[length(value) - 1]) then
      result:= value
    else if (pos(value, ' ') <= 0) and (pos(value, '"') <= 0) then
      result:= value
    else
      result:= '"' + AnsiReplaceStr(value, '"', '""') + '"';
  end;

function filenameContainsPath(const fileName: String): boolean;
  begin
    result:= (0 < pos('\', fileName)) or (0 < pos('\', fileName));
  end;

{$ifdef unix}
procedure doIgnoreChildProc;
  var sigact: sigactionrec;
  begin
    sigact.sa_flags := SA_NOCLDWAIT;
    FPSigaction(SIGCHLD, @sigact, nil);
  end;
{$endif}

initialization
  {$ifdef unix}
    //doIgnoreChildProc
    //signal(SIGPIPE, SIG_IGN);
  {$endif}
end.
