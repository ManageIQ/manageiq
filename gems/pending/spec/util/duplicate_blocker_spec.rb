require "logger"
require "util/duplicate_blocker"
require "timecop"

describe DuplicateBlocker do
  let(:threshold)      { @dedup_handler.duplicate_threshold }
  let(:slot_width)     { @dedup_handler.window_slot_width }
  let(:time_window)    { @dedup_handler.duplicate_window }
  let(:dups_per_log)   { @dedup_handler.progress_threshold }
  let(:purging_period) { @dedup_handler.purging_period }
  let(:short_time)     { 0.1 }
  let(:long_time)      { 0.4 }

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
        handler.duplicate_threshold = 15
        handler.duplicate_window    = 4
        handler.window_slot_width   = 0.3
        handler.progress_threshold  = 3
      end

      dedup_instance_method :target_method
      dedup_class_method :target_class_method
    end.new

    @dedup_handler = @test_object.class.dedup_handler
    @base_time = Time.now
  end

  it 'should allow the first few target method calls to pass even though they arrive with short intervals' do
    assert_safe_calls(:instance, threshold, @base_time, short_time, 'arg')
  end

  it 'should raise an error when the same target method has been called many times within a short interval' do
    assert_safe_calls(:instance, threshold, @base_time, short_time, 'arg')
    assert_error_call(:instance, @base_time + threshold * short_time + slot_width, 'arg')
  end

  it 'should raise an error when the same target class method has been called many times within a short interval' do
    assert_safe_calls(:class, threshold, @base_time, short_time, 'arg')
    assert_error_call(:class, @base_time + threshold * short_time + slot_width, 'arg')
  end

  it 'should allow the same target method call to pass many times as long as they arrive with long intervals' do
    assert_safe_calls(:instance, threshold + 5, @base_time, long_time, 'arg')
  end

  it 'should allow the once blocked target method call to pass when the interval is long enough' do
    # OK for the first few times
    assert_safe_calls(:instance, threshold, @base_time, short_time, 'arg')

    # blocking further calls
    assert_error_call(:instance, @base_time + threshold * short_time + slot_width, 'arg')
    assert_error_call(:instance, @base_time + (threshold + 1) * short_time + slot_width, 'arg')

    # back to normal if call is after a long interval
    assert_safe_calls(:instance, 2, @base_time + time_window + slot_width * 2, short_time, 'arg')
  end

  it 'should treat a target method with different arguments as different calls using default handler' do
    assert_safe_calls(:instance, threshold, @base_time, short_time, 'this arg')
    assert_safe_calls(:instance, threshold, @base_time + threshold * short_time, short_time, 'another arg')
  end

  it 'should log warning when the number of blocked target method calls reach preset value' do
    assert_safe_calls(:instance, threshold, @base_time, short_time,  'arg')
    t = @base_time + threshold * short_time + slot_width
    assert_error_call(:instance, t, 'arg')

    expect(@dedup_handler.logger).to receive(:warn).twice
    (dups_per_log * 2).times do
      t += short_time
      assert_error_call(:instance, t, 'arg')
    end
  end

  it 'should only return nil when the target method is blocked if the throw_exception_when_blocked flag is off' do
    @dedup_handler.throw_exception_when_blocked = false
    assert_safe_calls(:instance, threshold, @base_time, short_time, 'arg')
    assert_nil_call(:instance, @base_time + threshold * short_time + slot_width, 'arg')
  end

  it 'should accept user provided key and description' do
    # redefine the key; every call is considered as duplicate
    @dedup_handler.key_generator = ->(_meth, *_args) { "same_key" }
    @dedup_handler.descriptor = ->(_meth, *_args) { "call with redefined user key" }
    assert_safe_calls(:instance, 1, @base_time, short_time, 'arg1', 'arg2')
    assert_safe_calls(:class, 1, @base_time + short_time, short_time, 'arg3')
    assert_safe_calls(:instance, threshold - 2, @base_time + 2 * short_time, short_time)
    assert_error_call(:instance, @base_time + threshold * short_time + slot_width, 'arg4')
  end

  it 'should explicitly remove outdated history' do
    assert_safe_calls(:instance, 1, @base_time, short_time, 'arg1', 'arg2')
    assert_safe_calls(:class, 1, @base_time + short_time, short_time, 'arg3')
    assert_safe_calls(:instance, 1, @base_time + time_window / 2 + short_time * 2, short_time, 'arg1', 'arg2')
    later_time = @base_time + time_window + short_time * 3
    Timecop.freeze(later_time) do
      expect(@dedup_handler.histories.size).to eq(2)
      @dedup_handler.purge_histories(later_time)
      expect(@dedup_handler.histories.size).to eq(1)
    end
  end

  it 'should automatically remove outdated history' do
    assert_safe_calls :instance, 1, @base_time, short_time, 'arg1', 'arg2'
    assert_safe_calls :class, 1, @base_time + short_time, short_time, 'arg3'
    later_time = @base_time + purging_period + 1
    Timecop.freeze(later_time) do
      assert_safe_calls :instance, 1, later_time, short_time, 'arg1', 'arg2'
      expect(@dedup_handler.histories.size).to eq(1)
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
      make_a_call(meth, time) { |func| expect(func.call(*args)).to eq(args) }
      time += interval
    end
  end

  def assert_error_call(meth, time, *args)
    make_a_call(meth, time) do |func|
      expect { func.call(*args) }.to raise_error(DuplicateBlocker::DuplicateFoundException)
    end
  end

  def assert_nil_call(meth, time, *args)
    make_a_call(meth, time) { |func| expect(func.call(*args)).to be_nil }
  end
end
