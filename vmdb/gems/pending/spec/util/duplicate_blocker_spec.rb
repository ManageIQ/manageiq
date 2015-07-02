require "spec_helper"
require "logger"
require "util/duplicate_blocker"
require "timecop"

describe DuplicateBlocker do
  THRESHOLD    = 15
  TIME_WINDOW  = 4
  SLOT_WIDTH   = 0.3
  SHORT_TIME   = 0.1
  LONG_TIME    = 0.4
  DUPS_PER_LOG = 3

  before do
    @test_object = Class.new do
      include DuplicateBlocker

      def target_method(*args)
        args  # do nothing, return the arguments
      end

      def self.target_class_method(*args)
        args  # do nothing, return the arguments
      end

      dedup_handler do |handler|
        require 'stringio'
        handler.logger              = Logger.new(StringIO.new)
        handler.duplicate_threshold = THRESHOLD
        handler.duplicate_window    = TIME_WINDOW
        handler.window_slot_width   = SLOT_WIDTH
        handler.progress_threshold  = DUPS_PER_LOG
      end

      dedup_instance_method :target_method
      dedup_class_method :target_class_method
    end.new

    @dedup_handler = @test_object.class.dedup_handler
    @base_time = Time.now
  end

  it 'should allow the first few target method calls to pass even though they arrive with short intervals' do
    assert_safe_calls :instance, THRESHOLD, @base_time, SHORT_TIME, 'arg'
  end

  it 'should raise an error when the same target method has been called many times within a short interval' do
    assert_safe_calls :instance, THRESHOLD, @base_time, SHORT_TIME, 'arg'
    assert_error_call :instance, @base_time + THRESHOLD * SHORT_TIME + SLOT_WIDTH, 'arg'
  end

  it 'should raise an error when the same target class method has been called many times within a short interval' do
    assert_safe_calls :class, THRESHOLD, @base_time, SHORT_TIME, 'arg'
    assert_error_call :class, @base_time + THRESHOLD * SHORT_TIME + SLOT_WIDTH, 'arg'
  end

  it 'should allow the same target method call to pass many times as long as they arrive with long intervals' do
    assert_safe_calls :instance, THRESHOLD + 5, @base_time, LONG_TIME, 'arg'
  end

  it 'should allow the once blocked target method call to pass when the interval is long enough' do
    # OK for the first few times
    assert_safe_calls :instance, THRESHOLD, @base_time, SHORT_TIME, 'arg'

    # blocking further calls
    assert_error_call :instance, @base_time + THRESHOLD * SHORT_TIME + SLOT_WIDTH, 'arg'
    assert_error_call :instance, @base_time + (THRESHOLD + 1) * SHORT_TIME + SLOT_WIDTH, 'arg'

    # back to normal if call is after a long interval
    assert_safe_calls :instance, 2, @base_time + TIME_WINDOW + SLOT_WIDTH * 2, SHORT_TIME, 'arg'
  end

  it 'should treat a target method with different arguments as different calls using default handler' do
    assert_safe_calls :instance, THRESHOLD, @base_time, SHORT_TIME, 'this arg'
    assert_safe_calls :instance, THRESHOLD, @base_time + THRESHOLD * SHORT_TIME, SHORT_TIME, 'another arg'
  end

  it 'should log warning when the number of blocked target method calls reach preset value' do
    assert_safe_calls :instance, THRESHOLD, @base_time, SHORT_TIME,  'arg'
    t = @base_time + THRESHOLD * SHORT_TIME + SLOT_WIDTH
    assert_error_call :instance, t, 'arg'

    @dedup_handler.logger.should_receive(:warn).twice
    (DUPS_PER_LOG * 2).times do
      t += SHORT_TIME
      assert_error_call :instance, t, 'arg'
    end
  end

  it 'should only return nil when the target method is blocked if the throw_exception_when_blocked flag is off' do
    @dedup_handler.throw_exception_when_blocked = false
    assert_safe_calls :instance, THRESHOLD, @base_time, SHORT_TIME, 'arg'
    assert_nil_call :instance, @base_time + THRESHOLD * SHORT_TIME + SLOT_WIDTH, 'arg'
  end

  it 'should accept user provided key and description' do
    # redefine the key; every call is considered as duplicate
    @dedup_handler.key_generator = proc { |_meth, *_args| "same_key" }
    @dedup_handler.descriptor = proc { |_meth, *_args| "call with redefined user key" }
    assert_safe_calls :instance, 1, @base_time, SHORT_TIME, 'arg1', 'arg2'
    assert_safe_calls :class, 1, @base_time + SHORT_TIME, SHORT_TIME, 'arg3'
    assert_safe_calls :instance, THRESHOLD - 2, @base_time + 2 * SHORT_TIME, SHORT_TIME
    assert_error_call :instance, @base_time + THRESHOLD * SHORT_TIME + SLOT_WIDTH, 'arg4'
  end

  it 'should remove outdated history' do
    assert_safe_calls :instance, 1, @base_time, SHORT_TIME, 'arg1', 'arg2'
    assert_safe_calls :class, 1, @base_time + SHORT_TIME, SHORT_TIME, 'arg3'
    assert_safe_calls :instance, 1, @base_time + TIME_WINDOW / 2 + SHORT_TIME * 2, SHORT_TIME, 'arg1', 'arg2'
    Timecop.freeze(@base_time + TIME_WINDOW + SHORT_TIME * 3) do
      @dedup_handler.histories.size.should eq 2
      @dedup_handler.purge_histories
      @dedup_handler.histories.size.should eq 1
    end
  end

  private

  def make_a_call(meth, time)
    Timecop.freeze(time) do
      if meth == :instance
        yield @test_object.method(:target_method)
      else
        yield @test_object.class.method(:target_class_method)
      end
    end
  end

  def assert_safe_calls(meth, n, time, interval, *args)
    n.times do
      make_a_call(meth, time) { |func| func.call(*args).should eq args }
      time += interval
    end
  end

  def assert_error_call(meth, time, *args)
    make_a_call(meth, time) do |func|
      expect { func.call(*args) }.to raise_error(DuplicateBlocker::DuplicateFoundException)
    end
  end

  def assert_nil_call(meth, time, *args)
    make_a_call(meth, time) { |func| func.call(*args).should be nil }
  end
end
