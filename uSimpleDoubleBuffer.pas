//双缓冲的简单实现，单生产者单消费者，2个内部缓冲区的交换策略只是简单的考虑。
//janker 2018-04-05

unit uSimpleDoubleBuffer;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections;

const
  MinBufferCapaticy = 512;

type
  TSimpleDoubleBufferQueue<T> = class
  private
    FQueueA: TQueue<T>;
    FQueueB: TQueue<T>;
    FProducerQueue: TQueue<T>;
    FConsumerQueue: TQueue<T>;
    FCapaticy: Integer;
    FMinSwitchCount: Integer;
    FSwitchCount: Integer;

    procedure Switch;
    procedure InitBuffer;
    procedure SetMinSwitchCount(const Value: Integer);
    function GetProducerCount: Integer;
    function GetConsumerCount: Integer;
  public
    constructor Create(const Capaticy: Integer = MinBufferCapaticy; const AMinSwitchCount: Integer = 1);
    destructor Destroy; override;

    function Get: T;
    procedure Put(const Value: T);
    procedure Clear;

    property MinSwitchCount: Integer read FMinSwitchCount write SetMinSwitchCount;
    property ProducerCount: Integer read GetProducerCount;
    property ConsumerCount: Integer read GetConsumerCount;
    //test
    property SwitchCount: Integer read FSwitchCount;

  end;

implementation


{ TSimpleDoubleBufferQueue<T> }

procedure TSimpleDoubleBufferQueue<T>.Clear;
begin
  FProducerQueue.Clear;
  FConsumerQueue.Clear;
end;

constructor TSimpleDoubleBufferQueue<T>.Create(const Capaticy: Integer; const AMinSwitchCount: Integer);
begin
  FCapaticy := Capaticy;
  if FCapaticy < MinBufferCapaticy then
    FCapaticy := MinBufferCapaticy;
  FMinSwitchCount := AMinSwitchCount;
  if FMinSwitchCount < 1 then
    FMinSwitchCount := 1;

  InitBuffer;
end;

destructor TSimpleDoubleBufferQueue<T>.Destroy;
begin
  FQueueB.Free;
  FQueueA.Free;

  inherited;
end;

procedure TSimpleDoubleBufferQueue<T>.InitBuffer;
begin
  FQueueA := TQueue<T>.Create;
  FQueueA.Capacity := FCapaticy;
  FQueueB := TQueue<T>.Create;
  FQueueB.Capacity := FCapaticy;

  FProducerQueue := FQueueA;
  FConsumerQueue := FQueueB;
end;


procedure TSimpleDoubleBufferQueue<T>.Put(const Value: T);
begin

  if FProducerQueue.Count <= FProducerQueue.Capacity then
  begin
    TMonitor.Enter(FProducerQueue);
    try
      FProducerQueue.Enqueue(Value);
    finally
      TMonitor.Exit(FProducerQueue);
    end;

  end;
  if FProducerQueue.Count = FProducerQueue.Capacity  then
  begin
    { TODO 这里要挂起，要用更好的实现，下面的循环等待不好 2018-03-07}
    repeat
      if FConsumerQueue.Count <=0 then
        Break;
      TThread.Sleep(1);
    until FProducerQueue.Count < FProducerQueue.Capacity;
  end;

  if (FProducerQueue.Count >= FMinSwitchCount) and (FConsumerQueue.Count <= 0) then
    Switch;
end;

function TSimpleDoubleBufferQueue<T>.Get: T;
begin

  if FConsumerQueue.Count > 0 then
  begin
    TMonitor.Enter(FConsumerQueue);
    try
      Result := FConsumerQueue.Dequeue;
    finally
      TMonitor.Exit(FConsumerQueue);
    end;

  end;
  if (FConsumerQueue.Count <= 0) and (FProducerQueue.Count >= FMinSwitchCount) then
  begin
    Switch;
  end
  else
  begin
    { TODO 这里要挂起，要用更好的实现，下面的循环等待不好 2018-03-07}
    repeat
      if FProducerQueue.Count <= 0 then
        Break;
      TThread.Sleep(1);
    until FConsumerQueue.Count > 0;
  end;
end;

function TSimpleDoubleBufferQueue<T>.GetConsumerCount: Integer;
begin
  Result := FConsumerQueue.Count;
end;

function TSimpleDoubleBufferQueue<T>.GetProducerCount: Integer;
begin
  Result := FProducerQueue.Count;
end;

procedure TSimpleDoubleBufferQueue<T>.SetMinSwitchCount(const Value: Integer);
begin
  if FMinSwitchCount <> Value then
  begin
    FMinSwitchCount := Value;
  end;
end;

procedure TSimpleDoubleBufferQueue<T>.Switch;
var
  tmpPointer: TQueue<T>;
begin
  if (FConsumerQueue.Count > 0) {or (FProducerQueue.Count <= FMinSwitchCount)} then
    Exit;
  if (FProducerQueue.Count < FMinSwitchCount) then
    Exit;

  TMonitor.Enter(FConsumerQueue);
  TMonitor.Enter(FProducerQueue);
  //TMonitor.Enter(FConsumerQueue);
  try

    Inc(FSwitchCount);  //test
    tmpPointer := FProducerQueue;
    FProducerQueue := FConsumerQueue;
    FConsumerQueue := tmpPointer;

    TThread.Sleep(5);  //这个好像没啥用
  finally
    //TMonitor.Exit(FConsumerQueue);
    TMonitor.Exit(FProducerQueue);
    TMonitor.Exit(FConsumerQueue);

  end;
end;

end.
