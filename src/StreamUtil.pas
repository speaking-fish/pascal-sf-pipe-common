{$include project.inc}
unit StreamUtil;

interface uses
  {$ifdef unix}
    dynlibs, cthreads, baseunix, unix, linux,
  {$else}
    Windows,
  {$endif}
  Types, SysUtils, Math, Classes,
  {$ifdef fpc}
    Pipes,
  {$endif}
  SyncObjs;

type

  // single reader / single writer
  TQueue = class
  protected
    _buffer    : pointer;
    _bufferSize: integer;
    _capacity  : integer;

    _head      : integer;
    _tail      : integer;

    _accessCriticalSection: TCriticalSection;
    //fGetCriticalSection: TCriticalSection;
    //fPutCriticalSection: TCriticalSection;

    procedure setTail(tail: integer);
    procedure setHead(head: integer);

    property bufferSize: integer read _bufferSize;

  public
    constructor create(capacity: integer);
    destructor destroy(); override;

    function  putData(const data; count: integer): boolean;
    procedure getData(var   data; count: integer);

    procedure clear();

    function dataAvail(): integer;
    function vacant   (): integer;

    property capacity       : integer          read _capacity             ;
    property criticalSection: TCriticalSection read _accessCriticalSection;
  end;

  TCommonStream = class(TStream)
  public
    procedure flush(); virtual; abstract;
    function tryGetBytesAvailable(): longint; virtual; abstract;
  end;

  TShadowWriteStream = class(TCommonStream)
  protected
    _ownStream      : boolean;
    _stream         : TStream;
    _ownShadowStream: boolean;
    _shadowStream   : TStream;
  public
    constructor create(
      ownStream      : boolean;
      stream         : TStream;
      ownShadowStream: boolean;
      shadowStream   : TStream
      );
    destructor destroy; override;
    function write(const buffer; count: longint): longint; override;
    procedure flush(); override;
  end;

  TSplitStream = class(TCommonStream)
  protected
    _input : TStream;
    _output: TStream;
  public
    constructor create(
      input : TStream;
      output: TStream
      );
    function read (var   buffer; count: longint): longint; override;
    function write(const buffer; count: longint): longint; override;
    function tryGetBytesAvailable(): longint; override;
    procedure flush(); override;
    property input : TStream read _input ;
    property output: TStream read _output;
  end;

  TAbstractDelegateStream = class(TCommonStream)
  protected
    _origin: TStream;
  public
    constructor create(
      origin: TStream
      );
    property origin: TStream read _origin;
  end;

  TInputDelegateStream = class(TAbstractDelegateStream)
  public
    function read (var   buffer; count: longint): longint; override;
    function tryGetBytesAvailable(): longint; override;
  end;

  TOutputDelegateStream = class(TAbstractDelegateStream)
  public
    function write(const buffer; count: longint): longint; override;
    procedure flush(); override;
  end;

  TStreamReadEvent                = function (sender: TObject; var   buffer; count: longint): longint of object;
  TStreamWriteEvent               = function (sender: TObject; const buffer; count: longint): longint of object;
  TStreamTryGetBytesAvailableEvent= function (sender: TObject                              ): longint of object;
  TStreamFlushEvent               = procedure(sender: TObject                              )          of object;

  TCustomDelegateStream = class(TAbstractDelegateStream)
  protected
    _onRead                : TStreamReadEvent                ;
    _onWrite               : TStreamWriteEvent               ;
    _onTryGetBytesAvailable: TStreamTryGetBytesAvailableEvent;
    _onFlush               : TStreamFlushEvent               ;
  public
    function  read                (var   buffer; count: longint): longint; override;
    function  write               (const buffer; count: longint): longint; override;
    function  tryGetBytesAvailable(                            ): longint; override;
    procedure flush               (                            )         ; override;

    property onRead                : TStreamReadEvent                 read _onRead                 write _onRead                ;
    property onWrite               : TStreamWriteEvent                read _onWrite                write _onWrite               ;
    property onTryGetBytesAvailable: TStreamTryGetBytesAvailableEvent read _onTryGetBytesAvailable write _onTryGetBytesAvailable;
    property onFlush               : TStreamFlushEvent                read _onFlush                write _onFlush               ;
  end;

  TPushbackReadStream = class(TCommonStream)
  protected
    _input: TStream;
    _pushbackBuffer: TByteDynArray;
    _pushbackBufferSize: integer;
  public
    constructor create(input: TStream);
    function  read    (var   buffer; count: longint): longint; override;
    procedure pushback(const buffer; count: longint);
    function buffered(): integer;
    function tryGetBytesAvailable(): longint; override;
    property input : TStream read _input ;
  end;

  TNormalHandleStream = class(TCommonStream)
  protected
    _origin: THandleStream;
    {$ifdef windows}
      _maxReadCount: longint;
    {$endif}
  public
    constructor create(handle_: THandle);
    destructor destroy(); override;
    function read(var buffer; count: longint): longint; override;
    function write(const buffer; count: longint): longint; override;
    procedure flush(); override;
    function tryGetBytesAvailable(): longint; override;
    procedure close(); virtual;
    function handle(): integer;
  end;

  TInternalPipeHelper = class
  end;

  TLockBufferStream = class(TCommonStream)
  protected
    _queue: TQueue;
    _waitForDataMs: longint;
  public
    constructor create(capacity: integer; waitForDataMs: longint);
    destructor destroy(); override;
    function read(var buffer; count: longint): longint; override;
    function write(const buffer; count: longint): longint; override;
    procedure flush(); override;
    function tryGetBytesAvailable(): longint; override;
  end;

  TLockBufferHelper = class
  protected
    _output: TOutputDelegateStream;
    _input : TInputDelegateStream ;
    _impl  : TLockBufferStream    ;
  public
    constructor create(capacity: integer; waitForDataMs: longint);
    destructor destroy(); override;
    property output: TOutputDelegateStream read _output;
    property input : TInputDelegateStream  read _input ;
  end;

  // no interfaces used in execute
  // no memalloc in execute
  TStreamGobbler = class(TThread)
  protected
  //_input : THandle;
    _inputHandle: THandle;
    _inputStream: TNormalHandleStream;
    _output: TStream;
    _buffer: TByteDynArray;
    _lastActivityCounter: integer;
    procedure execute(); override;
    procedure update(); virtual;
  public
    constructor create(input: THandle; output: TStream; createSuspended: boolean);
    destructor destroy; override;
    procedure terminate;
    function lastActivityCounter(): integer;
  end;

  TStreamGobblerWatchdog = class(TThread)
  protected
    _gobbler: TStreamGobbler;
    _timeout: dword;
    _terminationEvent: TEvent;
    procedure execute(); override;
    procedure doTerminate(); override;
  public
    constructor create(gobbler: TStreamGobbler; timeout: dword; createSuspended: boolean);
    destructor destroy; override;
    procedure terminate;
  end;

  TStreamCopier = class(TThread)
  protected
    _bufferSize   : integer;
    _buffer       : pointer;
    _ownInput     : boolean;
    _input        : TStream;
    _ownOutput    : boolean;
    _output       : TStream;
    _name         : String ;
    _readPhaseLock: TCriticalSection;
    _readPhase    : boolean;
    _startReadTick: DWORD;
    procedure execute; override;
  public
    constructor create(ownInput: boolean; input: TStream; ownOutput: boolean; output: TStream; name: String);
    destructor destroy; override;
    procedure terminate;
    function isTerminated(): boolean;
    function checkToTerminate(tickCount: DWORD): boolean;
  end;

  TStreamCopierWatchdog = class(TThread)
  protected
    _copier          : TStreamCopier;
    _timeout         : dword;
    _terminationEvent: TEvent;
    _enabled         : boolean;
    _enabledLock     : TCriticalSection;
    procedure execute(); override;
  public
    constructor create(copier: TStreamCopier; timeout: dword; createSuspended: boolean);
    destructor destroy; override;
    procedure terminate;
    function enabled(): boolean;
    procedure setEnabled(value: boolean);
  end;

procedure flushStream(stream: THandleStream);
procedure tryFlushStream(stream: TStream);

// returns -1        = unknown
//         otherwise = bytes available
function tryGetBytesAvailable(stream: TStream): longint;

function tryReadAvailableBytes      (stream: TStream; var buffer; count: longint): longint;
function tryReadAvailableBytesOrLock(stream: TStream; var buffer; count: longint): longint;

function getFileBytes(const fileName: String): TByteDynArray;

{
function handleGetCommTimeouts(handle: THandle): COMMTIMEOUTS;
procedure handleSetCommTimeouts(handle: THandle; const params: COMMTIMEOUTS);
}

function writeTo(dest: TStream; const value: AnsiString   ; flush: boolean): longint; overload;
function writeTo(dest: TStream; const value: TByteDynArray; flush: boolean): longint; overload;

function makeAnsiString(buffer: pointer; left: integer; right: integer): AnsiString; overload;
function makeAnsiString(count: integer; c: ansichar): AnsiString; overload;

function OpenCreateFileStream(
  const FileName: String; mode: word
  ): TFileStream;

{$ifndef unix}
function FileOpenCreate(
  const FileName: String; DesiredAccess, ShareMode, FileAttributes: Integer
  ): THandle;
{$endif}

procedure createOverwriteFile(const fileName: String; const value: AnsiString);

{$ifdef unix}
function GetTickCount64: QWord;
function GetTickCount: DWord;
{$endif}

type
  //THandleStreamCreateConstructor = function(AClass: TClass; CreateNewInstance: Boolean; AHandle: Integer): THandleStream;

  EFOpenCreateError = class(EStreamError);

resourcestring
  SFOpenCreateError = 'Cannot open/create file %s';

implementation

{ TQueue -------------------------------------------------------------------- }

constructor TQueue.create(capacity: integer);
  begin
    inherited create();
    _capacity:= capacity;
    _bufferSize:= capacity + 1;
    getMem(_buffer, bufferSize);
    //PutCriticalSection:= TCriticalSection.create;
    //GetCriticalSection:= TCriticalSection.create;
    _accessCriticalSection:= TCriticalSection.create();
  end;

destructor TQueue.destroy;
  begin
    _accessCriticalSection.free();
    _accessCriticalSection:= nil;
    inherited destroy();
    freeMem(_buffer);
    _buffer:= nil;
    //PutCriticalSection.free;
    //PutCriticalSection:= nil;
    //GetCriticalSection.free;
    //GetCriticalSection:= nil;
  end;

procedure TQueue.setTail(tail: integer);
  begin
    _accessCriticalSection.enter();
    try
      _tail:= tail;
    finally
      _accessCriticalSection.leave();
    end;
  end;

procedure TQueue.setHead(head: Integer);
  begin
    _accessCriticalSection.enter();
    try
      _head:= head;
    finally
      _accessCriticalSection.leave();
    end;
  end;

function TQueue.putData(const data; count: integer): boolean;
  var
    aTail, aCount: Integer;
  begin
    result:= false;
    if count > 0 then
      begin
        //fPutCriticalSection.enter;
        //try
          if vacant >= count then
            begin
              aTail:= _tail;
              aCount:= count;
              if aTail + aCount >= bufferSize then
                aCount:= bufferSize - aTail;
              move(data, PChar(_buffer)[aTail], aCount);
              count:= count - aCount;
              aTail:= aTail + aCount;
              if aTail >= bufferSize then
                begin
                  aTail:= 0;
                  if count > 0 then
                    begin
                      move(PChar(@data)[aCount], _buffer^, count);
                      aTail:= count;
                    end;
                end;
              setTail(aTail);
              result:= true;
            end{
          else
            raise Exception.createFmt(
              'TQueue: buffer overflow.'^M^J +
              ' avail=%d but put count=%d (total buffer size=%d)',
              [aAvail, count, size]
              )};
        //finally
        //  fPutCriticalSection.leave;
        //end;
      end;
  end;

procedure TQueue.getData(var data; count: integer);
  var
    aAvail: Integer;
    aHead : Integer;
    aCount: Integer;
  begin
    if count > 0 then
      begin
        //fGetCriticalSection.enter;
        //try
          aAvail:= dataAvail;
          if aAvail >= count then
            begin
              aHead:= _head;
              aCount:= count;
              if aHead + aCount >= bufferSize then
                aCount:= bufferSize - aHead;
              move(PChar(_buffer)[aHead], data, aCount);
              count:= count - aCount;
              aHead:= aHead + aCount;
              if aHead >= bufferSize then
                begin
                  aHead:= 0;
                  if count > 0 then
                    begin
                      move(_buffer^, PChar(@data)[aCount], count);
                      aHead:= count;
                    end;
                end;
              _head:= aHead;
            end
          else
            raise Exception.createFmt(
              'TQueue: reading unavailable data size.'^M^J +
              ' data avail=%d but get count=%d (capacity=%d)',
              [aAvail, count, capacity]
              );
        //finally
        //  GetCriticalSection.Leave;
        //end;
      end;
  end;

function TQueue.dataAvail: integer;
  var
    AHead, ATail: Integer;
  begin
    _accessCriticalSection.enter();
    try
      aHead:= _head;
      aTail:= _tail;
    finally
      _accessCriticalSection.leave();
    end;
    if aTail < aHead then
      aTail:= bufferSize + aTail;
    result:= aTail - aHead;
  end;

function TQueue.vacant: Integer;
  begin
    result:= bufferSize - dataAvail - 1;
  end;

procedure TQueue.clear;
  begin
    _accessCriticalSection.enter();
    try
      _head:= _tail;
    finally
      _accessCriticalSection.leave();
    end;
  end;

constructor TSplitStream.create(
  input : TStream;
  output: TStream
  );
  begin
    inherited create();
    _input := input;
    _output:= output;
  end;

function TSplitStream.read (var   buffer; count: longint): longint;
                                                                    begin result:= _input .read (buffer, count); end;
function TSplitStream.write(const buffer; count: longint): longint;
                                                                    begin result:= _output.write(buffer, count); end;
function TSplitStream.tryGetBytesAvailable(): longint;
                                                                    begin result:= StreamUtil.tryGetBytesAvailable(_input); end;
procedure TSplitStream.flush();
                                                                    begin                          tryFlushStream(_output); end;



constructor TAbstractDelegateStream.create(
  origin: TStream
  );
  begin
    inherited create();
    _origin:= origin;
  end;

function TInputDelegateStream .read (var   buffer; count: longint): longint;
  begin result:=       _origin.read(buffer, count); end;

function TInputDelegateStream .tryGetBytesAvailable(): longint;
  begin result:=    StreamUtil.tryGetBytesAvailable(_origin); end;

function TOutputDelegateStream.write(const buffer; count: longint): longint;
  begin result:=       _origin.write(buffer, count); end;

procedure TOutputDelegateStream.flush();
  begin                      tryFlushStream(_origin); end;


function  TCustomDelegateStream.read                (var   buffer; count: longint): longint;
  begin if assigned(          onRead                    ) then
          result:=            onRead(self, buffer, count) else
          result:=       origin.read(      buffer, count);
  end;

function  TCustomDelegateStream.write               (const buffer; count: longint): longint;
  begin if assigned(          onWrite                    ) then
          result:=            onWrite(self, buffer, count) else
          result:=       origin.write(      buffer, count);
  end;

function  TCustomDelegateStream.tryGetBytesAvailable(                            ): longint;
  begin if assigned(          onTryGetBytesAvailable       ) then
          result:=            onTryGetBytesAvailable(self  ) else
          result:=   StreamUtil.tryGetBytesAvailable(origin);

  end;

procedure TCustomDelegateStream.flush               (                            )         ;
  begin if assigned(          onFlush             ) then
                              onFlush      (self  ) else
                  StreamUtil.tryFlushStream(origin);
  end;

constructor TPushbackReadStream.create(input: TStream);
  begin
    inherited create();
    _input:= input;
  end;

function TPushbackReadStream.read(var buffer; count: longint): longint;
  var fromBuffer: integer;
  begin
    result:= 0;
    fromBuffer:= min(_pushbackBufferSize, count);
    if 0 < fromBuffer then
      begin
        move(_pushbackBuffer[0], buffer, fromBuffer);
        if fromBuffer < _pushbackBufferSize then
          move(_pushbackBuffer[fromBuffer], _pushbackBuffer[0], _pushbackBufferSize - fromBuffer);
        _pushbackBufferSize:= _pushbackBufferSize - fromBuffer;
        count:= count - fromBuffer;
        result:= fromBuffer;
        exit;
      end;
    if 0 < count then
      result:= result + _input.read(PByteArray(@buffer)^[fromBuffer], count);
  end;

procedure TPushbackReadStream.pushback(const buffer; count: longint);
  var newSize: integer;
  begin
    if count <= 0 then
      exit;

    if 0 = length(_pushbackBuffer) then
      setLength(_pushbackBuffer, 1024);

    newSize:= _pushbackBufferSize + count;

    while length(_pushbackBuffer) < newSize do
      setLength(_pushbackBuffer, length(_pushbackBuffer) * 2);

    if 0 < _pushbackBufferSize then
      move(_pushbackBuffer[0], _pushbackBuffer[count], count);

    move(buffer, _pushbackBuffer[0], count);
    _pushbackBufferSize:= newSize;
  end;

function TPushbackReadStream.buffered(): integer;
  begin result:= _pushbackBufferSize; end;

function TPushbackReadStream.tryGetBytesAvailable(): longint;
  var avail: longint;
  begin
    result:= buffered();
    avail:= StreamUtil.tryGetBytesAvailable(_input);
    if 0 = result then
      result:= avail
    else if 0 < avail then
      result:= result + avail;
  end;



constructor TLockBufferStream.create(capacity: integer; waitForDataMs: longint);
  begin
    inherited create();
    _queue:= TQueue.create(capacity);
    _waitForDataMs:= waitForDataMs;
  end;

destructor TLockBufferStream.destroy();
  begin
    inherited destroy();
    _queue.free();
    _queue:= nil;
  end;

function TLockBufferStream.read(var buffer; count: longint): longint;
  var avail: integer;
  begin
    result:= 0;
    if 0 = count then
      exit;

    while true do
      begin
        avail:= _queue.dataAvail();
        if 0 = avail then
          begin
            sleep(_waitForDataMs);
            continue;

          end
        else if avail < count then
          begin
            _queue.getData(buffer, avail);
            result:= avail;
            exit;

          end
        else
          begin
            _queue.getData(buffer, count);
            result:= count;
            exit;

          end
      end;
  end;
  
function TLockBufferStream.write(const buffer; count: longint): longint;
  var vacant: integer;
  var p: pointer;
  begin
    result:= count;
    p:= @buffer;
    while 0 < count do
      begin
        vacant:= _queue.vacant;
        if 0 = vacant then
          begin
            sleep(_waitForDataMs);
            continue;

          end
        else if vacant < count then
          begin
            if not _queue.putData(p^, vacant) then
              begin
                sleep(_waitForDataMs);
                continue;

              end
            else
              begin
                count:= count - vacant;
                continue;

              end;
          end
        else
          begin
            if not _queue.putData(p^, count) then
              begin
                sleep(_waitForDataMs);
                continue;

              end
            else
              begin
                count:= count - count;
                exit;

              end;
          end;
      end;
  end;

procedure TLockBufferStream.flush();
  begin
  end;

function TLockBufferStream.tryGetBytesAvailable(): longint;
  begin
    result:= _queue.dataAvail();
  end;


constructor TLockBufferHelper.create(capacity: integer; waitForDataMs: longint);
  begin
    inherited create();
    _impl  := TLockBufferStream    .create(capacity, waitForDataMs);
    _output:= TOutputDelegateStream.create(_impl);
    _input := TInputDelegateStream .create(_impl);
  end;

destructor TLockBufferHelper.destroy();
  begin
    inherited destroy();
    
    _output.free();
    _output:= nil;

    _input.free();
    _input:= nil;

    _impl.free();
    _impl:= nil;
  end;

constructor TStreamGobbler.create(input: THandle; output: TStream; createSuspended: boolean);
  begin
    _inputHandle := input;
    _inputStream := TNormalHandleStream.create(_inputHandle);
    _output:= output;
    setLength(_buffer, 1024 * 1024);
    update();
    inherited create(createSuspended);
  end;

destructor TStreamGobbler.destroy();
  begin
    terminate();
    inherited destroy();
    _inputStream.free();
    _inputStream:= nil;
  end;

procedure TStreamGobbler.update();
  begin
    interlockedIncrement(_lastActivityCounter);
  end;

procedure TStreamGobbler.terminate();
  begin
    inherited terminate();
    try
      (*
      {$ifdef fpc}
        fileClose(_input);
      {$else}
        closeHandle(_input);
      {$endif}
      *)
      _inputStream.close();
    finally
      //_input:= {$ifndef unix} INVALID_HANDLE_VALUE {$else} 0 {$endif};
      _inputHandle:= {$ifndef unix} INVALID_HANDLE_VALUE {$else} 0 {$endif};
    end;
  end;

function TStreamGobbler.lastActivityCounter(): integer;
  begin
    result:= interlockedExchangeAdd(_lastActivityCounter, 0);
  end;

procedure TStreamGobbler.execute();
  var readCount : cardinal;
  var writeCount: longint ;
  var lastError : dword   ;
  begin
    while not terminated do
      begin
        readCount:= 0;
        update();
        (*
        {$ifdef fpc}
          readCount:= fileRead(_input, _buffer[0], length(_buffer));
        {$else}
          if not Windows.readFile(_input, _buffer[0], length(_buffer), readCount, nil) then
            begin
              lastError:= Windows.getLastError();
              if ERROR_NOT_ENOUGH_MEMORY = lastError then
                writeLn(errOutput, 'Error: Buffer size too long: ' + intToStr(length(_buffer)) + '.');
              exit;
            end;
        {$endif}
        *)
        try
           readCount:= tryReadAvailableBytesOrLock(_inputStream, _buffer[0], length(_buffer));
        except on e: Exception do exit;
        end;

        //if readCount <= 0 then
        //  exit;

        if readCount < 0 then
          exit
        else
          begin
            //update();
            //sleep(100);
          end;

        update();
        writeCount:= _output.write(_buffer[0], readCount);
        if writeCount <> readCount then
          exit;
      end;
  end;

constructor TStreamGobblerWatchdog.create(gobbler: TStreamGobbler; timeout: dword; createSuspended: boolean);
  begin
    _gobbler:= gobbler;
    _timeout:= timeout;
    _terminationEvent:= TEvent.create(nil, false, false, '');
    inherited create(createSuspended);
  end;

destructor TStreamGobblerWatchdog.destroy;
  begin
    terminate();
    inherited destroy();
    _terminationEvent.free();
    _terminationEvent:= nil;
  end;

procedure TStreamGobblerWatchdog.execute();
  var prevCounter   : integer;
  var currentCounter: integer;
  var waitResult: TWaitResult;
  begin
    prevCounter:= _gobbler.lastActivityCounter();
    while not terminated do
      begin
        waitResult:= _terminationEvent.waitFor(_timeout);
        if wrTimeout <> waitResult then
          exit;

        currentCounter:= _gobbler.lastActivityCounter();
        if currentCounter = prevCounter then
          begin
            _gobbler.terminate();
            exit;
          end;
        prevCounter:= currentCounter;
      end;
  end;

procedure TStreamGobblerWatchdog.doTerminate();
  begin
    _gobbler.terminate();
    inherited doTerminate();
  end;

procedure TStreamGobblerWatchdog.terminate;
  begin
    inherited terminate();
    _terminationEvent.setEvent();
  end;

//procedure TCommonStream.flush();
//  begin
//    // do nothing
//  end;
//
//function TCommonStream.tryGetBytesAvailable(): longint;
//  begin
//    result:= -1; // -1 = unknown
//  end;



constructor TShadowWriteStream.create(
  ownStream      : boolean;
  stream         : TStream;
  ownShadowStream: boolean;
  shadowStream   : TStream
  );
  begin
    inherited create();
    _ownStream      := ownStream      ;
    _stream         := stream         ;
    _ownShadowStream:= ownShadowStream;
    _shadowStream   := shadowStream   ;
  end;

destructor TShadowWriteStream.destroy;
  begin
    inherited destroy();

    if _ownStream then
      _stream.free();

    _stream:= nil;

    if _ownShadowStream then
      _shadowStream.free();

    _shadowStream:= nil;
  end;

function TShadowWriteStream.write(const buffer; count: longint): longint;
  begin
    result:= _stream.write(buffer, count);
    if assigned(_shadowStream) then
      _shadowStream.write(buffer, result);
  end;

procedure TShadowWriteStream.flush();
  begin
    tryFlushStream(_stream);
    if assigned(_shadowStream) then
      tryFlushStream(_shadowStream);
  end;

constructor TStreamCopier.create(
  ownInput : boolean; input : TStream;
  ownOutput: boolean; output: TStream;
  name: String
  );
  begin
    _bufferSize:= 1024 * 1024;
    _buffer    := getMemory(_bufferSize);
    _ownInput  := ownInput ;
    _input     := input    ;
    _ownOutput := ownOutput;
    _output    := output   ;
    _name      := name;
    _readPhaseLock:= TCriticalSection.create();
    inherited create(true);
  end;

destructor TStreamCopier.destroy;
  begin
    terminate();

    inherited;

    freeMemory(_buffer);
    _buffer:= nil;

    if _ownInput then
      _input.free();

    _input:= nil;

    if _ownOutput then
      _output.free();

    _output:= nil;

    _readPhaseLock.free();
    _readPhaseLock:= nil;
  end;

procedure TStreamCopier.terminate;
  begin
    if not terminated then
      begin
        inherited terminate();
        if handle <> 0 then
          begin
            {$ifdef fpc}
              killThread(handle);
            {$else}
              terminateThread(handle, 0);
            {$endif}
          end;
      end;
  end;

function TStreamCopier.isTerminated(): boolean;
  begin
    result:= terminated;
  end;

function TStreamCopier.checkToTerminate(tickCount: DWORD): boolean;
  var currentTick: DWORD;
  begin
    result:= false;
    _readPhaseLock.enter();
    try
      if _readPhase then
        begin
          currentTick:= getTickCount();
          dec(currentTick, _startReadTick);
          if tickCount <= currentTick then
            begin
              terminate();
              result:= true;
            end;
        end;
    finally
      _readPhaseLock.leave();
    end;
  end;

procedure TStreamCopier.execute;
  var readCount   : longint      ;
  var writeCount  : longint      ;
  begin
    //repeat
    while not terminated do
      begin
        _readPhaseLock.enter();
        try
          _readPhase:= true;
          _startReadTick:= getTickCount();
        finally
          _readPhaseLock.leave();
        end;
        try
          readCount:= _input.read(_buffer^, _bufferSize);

          {$ifndef unix}
            if ERROR_OPERATION_ABORTED = {$ifdef fpc} GetLastOSError() {$else} getLastError() {$endif} then
              exit;
          {$endif}


        finally
          _readPhaseLock.enter();
          try
            _readPhase:= false;
          finally
            _readPhaseLock.leave();
          end;
        end;
        if 0 = readCount then
          begin
            break;
            //sleep(100);
            //continue;
          end;
        repeat
          writeCount:= _output.write(_buffer^, readCount);
          tryFlushStream(_output);
          {$ifndef unix}
            if ERROR_OPERATION_ABORTED = {$ifdef fpc} GetLastOSError() {$else} getLastError() {$endif}  then
              exit;
          {$endif}
          if writeCount = readCount then
            break;
          move((pansichar(_buffer) + writeCount)^, _buffer^, readCount - writeCount);
          readCount:= readCount - writeCount;
        until false;
      end;
    //until false;
  end;

constructor TStreamCopierWatchdog.create(copier: TStreamCopier; timeout: dword; createSuspended: boolean);
  begin
    _copier := copier ;
    _timeout:= timeout;
    
    _terminationEvent:= TEvent.create(nil, false, false, '');
    _enabledLock     := TCriticalSection.create();
    inherited create(createSuspended);
  end;

destructor TStreamCopierWatchdog.destroy;
  begin
    terminate();
    inherited destroy();
    
    _terminationEvent.free();
    _terminationEvent:= nil;

    _enabledLock.free();
    _enabledLock:= nil;
  end;

procedure TStreamCopierWatchdog.execute();
  var waitResult: TWaitResult;
  begin
    while not terminated do
      begin
        waitResult:= _terminationEvent.waitFor(_timeout);
        if wrTimeout <> waitResult then
          exit;

        if enabled() then
          if _copier.checkToTerminate(_timeout) then
            exit;
      end;
  end;

procedure TStreamCopierWatchdog.terminate;
  begin
    inherited terminate();
    _terminationEvent.setEvent();
  end;

function TStreamCopierWatchdog.enabled(): boolean;
  begin
    _enabledLock.enter();
    try
      result:= _enabled;
    finally
      _enabledLock.leave();
    end;
  end;

procedure TStreamCopierWatchdog.setEnabled(value: boolean);
  begin
    _enabledLock.enter();
    try
      _enabled:= value;
    finally
      _enabledLock.leave();
    end;
  end;

constructor TNormalHandleStream.create(handle_: THandle);
  begin
    inherited create();
    _origin:= THandleStream.create(handle_);
    {$ifdef windows}
      _maxReadCount:= 0;
    {$endif}
  end;

destructor TNormalHandleStream.destroy();
  begin
    inherited destroy;
    _origin.free();
    _origin:= nil;
  end;

function TNormalHandleStream.read(var buffer; count: longint): longint;
  begin
    {$ifdef windows}
      if 0 < count then // leave default zero count behaviour
        if 0 < _maxReadCount then
          if _maxReadCount < count then
            begin
              count:= _maxReadCount;
            end;
    {$endif}
    while true do
      begin
        //result := fileRead(handle, buffer, count);
        result := fileRead(_origin.handle, buffer, count);
        if result = -1 then
          begin
            {$ifdef windows}
              if 0 < count then  // leave default zero count behaviour
                if ERROR_NOT_ENOUGH_MEMORY = {$ifdef fpc} GetLastOSError() {$else} GetLastError() {$endif} then
                  begin
                    if 128 < count then // absolute min
                      begin
                        count:= count div 2;
                        _maxReadCount:= count;
                        continue;

                      end;
                  end;
            {$endif}
            {$ifdef fpc} RaiseLastOSError();
            {$else} raise Exception.create('Error read: ' + sysErrorMessage(getLastError()));
            {$endif}
            //raise Exception.create('Error read: ' + sysErrorMessage({$ifdef fpc} getLastOSError() {$else} getLastError() {$endif} ));
            //Result := 0;
          end;

        break;

      end;
  end;

function TNormalHandleStream.write(const Buffer; Count: longint): longint;
  begin
    //result := fileWrite(handle, buffer, Count);
    result := fileWrite(_origin.handle, buffer, count);
    if result = -1 then
      {$ifdef fpc} RaiseLastOSError();
      {$else} raise Exception.create('Error read: ' + sysErrorMessage(getLastError()));
      {$endif}
      //raise Exception.create('Error write: ' + sysErrorMessage({$ifdef fpc} getLastOSError() {$else} getLastError() {$endif} ));
      //Result := 0;
  end;

procedure TNormalHandleStream.flush();
  begin
    //flushStream(self);
    flushStream(_origin);
  end;

function TNormalHandleStream.tryGetBytesAvailable(): longint;
  begin
    result:= StreamUtil.tryGetBytesAvailable(_origin);
  end;

procedure TNormalHandleStream.close();
  begin
    {$ifdef fpc}
      fileClose(_origin.handle);
    {$else}
      closeHandle(_origin.handle);
    {$endif}
  end;

function TNormalHandleStream.handle(): integer;
  begin
    result:= _origin.handle;
  end;

procedure flushStream(stream: THandleStream);
  begin
    {$ifndef unix}
      flushFileBuffers(stream.handle);
    {$else}
      fpfsync(stream.handle);
    {$endif}
  end;

procedure tryFlushStream(stream: TStream);
  begin
    {
         if       stream is TShadowWriteStream   then
                 (stream as TShadowWriteStream ).flush()
    else if       stream is TNormalHandleStream  then
                 (stream as TNormalHandleStream).flush()
    else if       stream is TSplitStream         then
                 (stream as TSplitStream       ).flush()
    }
         if       stream is TCommonStream        then
                 (stream as TCommonStream      ).flush()
    else if       stream is THandleStream        then
      flushStream(stream as THandleStream      )
    ;
  end;

function tryGetBytesAvailable(stream: TStream): longint;
  var temp: DWord;
  begin
    result:= -1;
    {$ifdef fpc}
      if          stream is TInputPipeStream then
        begin
          temp:= (stream as TInputPipeStream).numBytesAvailable;
          if temp < maxlongint then
            result:= temp else
            result:= maxlongint;
        end
      else
    {$endif}
    if          stream is TCommonStream  then
      result:= (stream as TCommonStream).tryGetBytesAvailable()
    {
    if          stream is TPushbackReadStream  then
      result:= (stream as TPushbackReadStream).tryGetBytesAvailable()
    else if     stream is TSplitStream         then
      result:= (stream as TSplitStream       ).tryGetBytesAvailable()
    }
    ;
  end;

function tryReadAvailableBytes(stream: TStream; var buffer; count: longint): longint;
  var avail: longint;
  begin
    avail:= tryGetBytesAvailable(stream);
    if avail < 0 then
      result:= stream.read(buffer, count)
    else if avail = 0 then
      result:= 0
    else // 0 < avail
      result:= stream.read(buffer, min(avail, count));
  end;

function tryReadAvailableBytesOrLock(stream: TStream; var buffer; count: longint): longint;
  var avail: longint;
  begin
    if 0 = count then
      begin
        result:= 0;
        exit;
      end;
    avail:= tryGetBytesAvailable(stream);
    if avail < 0 then
      begin
        result:= stream.read(buffer, count); // unknown avail - do locked read. returns actually available and read count
        //result:= stream.read(buffer, 1) // try locked read one byte
        if 0 = result then
          result:= -1; // 0 signal eof, -1 = still unknown
      end
    else if avail = 0 then
      begin
        result:= stream.read(buffer, count) // zero avail - do locked read. returns actually available and read count
        {
        result:= stream.read(buffer, 1); // try locked read one byte
        if 1 = result then
          begin
            if 1 < count then
              result:= tryReadAvailableBytes(stream, PByteArray(@buffer)[1], count - 1); // try read more available bytes
          end;
        }
      end
    else // 0 < avail
      result:= stream.read(buffer, min(avail, count));
  end;

function getFileBytes(const fileName: String): TByteDynArray;
  var stream: TFileStream;
  begin
    stream:= TFileStream.create(fileName, fmOpenRead + fmShareDenyWrite);
    try
      setLength(result, stream.size);
      stream.read(result[0], length(result));
    finally
      stream.free();
      stream:= nil;
    end;
  end;

function writeTo(dest: TStream; const value: AnsiString; flush: boolean): longint;
  begin
    result:= dest.write(pchar(value)^, length(value));
    if flush then
      tryFlushStream(dest);
  end;

function writeTo(dest: TStream; const value: TByteDynArray; flush: boolean): longint;
  begin
    result:= 0;
    if 0 < length(value) then
      result:= dest.write(value[0], length(value));
    if flush then
      tryFlushStream(dest);
  end;

function OpenCreateFileStream(
  const FileName: String; mode: word
  ): TFileStream;
  begin
    try
      result:= TFileStream.Create(FileName, fmCreate {$ifdef fpc} or mode {$endif}); // delphi check equal to fmCreate only
    except on e: Exception do
      begin
        result:= TFileStream.Create(FileName, mode);
      end;
    end;
  end;

{$ifndef unix}
function FileOpenCreate(
  const FileName: String; DesiredAccess, ShareMode, FileAttributes: Integer
  ): THandle;
  begin
    Result:= THandle(
      CreateFile(
        PChar(FileName),
        DesiredAccess  ,
        ShareMode      ,
        nil            ,
        OPEN_ALWAYS    ,
        FileAttributes ,
        0
        )
      );
  end;
{$endif}

procedure createOverwriteFile(const fileName: String; const value: AnsiString);
  var stream: TFileStream;
  begin
    stream:=
      openCreateFileStream(
        fileName,
        fmOpenWrite or fmShareDenyWrite
        );
    try
      writeTo(stream, value, false);
    finally
      stream.size:= stream.position;
      stream.free();
      stream:= nil;
    end;
  end;

function makeAnsiString(buffer: pointer; left: integer; right: integer): AnsiString; overload;
  begin
    setLength(result, right - left);
    move(buffer^, pansichar(result)^, length(result));
  end;

function makeAnsiString(count: integer; c: ansichar): AnsiString; overload;
  begin
    setLength(result, count);
    fillChar(pansichar(result)^, count, c);
  end;

{$ifdef unix}

function GetTickCount64: QWord;
  var tp: timespec;
  begin
    clock_gettime(CLOCK_MONOTONIC, @tp);
    result:= (Int64(tp.tv_sec) * 1000) + (tp.tv_nsec div 1000000);
  end;

function GetTickCount: DWord;
  begin
    result:= GetTickCount64();
  end;

{$endif}

end.

