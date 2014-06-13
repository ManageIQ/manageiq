require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-benchmark'

require 'timecop'

describe Benchmark do
  after(:each) { Timecop.return }

  it '.realtime_store' do
    timings = {}
    result = Benchmark.realtime_store(timings, :test1) do
      Timecop.travel(500)
      Benchmark.realtime_store(timings, :test2) do
        Timecop.travel(500)
        Benchmark.realtime_store(timings, :test3) do
          Timecop.travel(500)
        end
      end
      "test"
    end
    result.should == "test"
    timings[:test1].should be_within(0.01).of(1500)
    timings[:test2].should be_within(0.01).of(1000)
    timings[:test3].should be_within(0.01).of(500)
  end

  it '.realtime_store with an Exception' do
    timings = {}
    begin
      Benchmark.realtime_store(timings, :test1) do
        Timecop.travel(500)
        raise Exception
      end
    rescue Exception
      timings[:test1].should be_within(0.01).of(500)
    end
  end

  it '.realtime_block' do
    result, timings = Benchmark.realtime_block(:test1) do
      Timecop.travel(500)
      Benchmark.realtime_block(:test2) do
        Timecop.travel(500)
        Benchmark.realtime_block(:test3) do
          Timecop.travel(500)
        end
      end
      "test"
    end
    result.should == "test"
    timings[:test1].should be_within(0.01).of(1500)
    timings[:test2].should be_within(0.01).of(1000)
    timings[:test3].should be_within(0.01).of(500)
  end

  it '.in_realtime_block?' do
    Benchmark.in_realtime_block?.should be_false
    Benchmark.realtime_block(:test1) do
      Benchmark.in_realtime_block?.should be_true
    end
    Benchmark.in_realtime_block?.should be_false
  end
end
