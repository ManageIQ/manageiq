require 'util/extensions/miq-benchmark'
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
    expect(result).to eq("test")
    expect(timings[:test1]).to be_within(0.5).of(1500)
    expect(timings[:test2]).to be_within(0.5).of(1000)
    expect(timings[:test3]).to be_within(0.5).of(500)
  end

  it '.realtime_store with an Exception' do
    timings = {}
    begin
      Benchmark.realtime_store(timings, :test1) do
        Timecop.travel(500)
        raise Exception
      end
    rescue Exception
      expect(timings[:test1]).to be_within(0.5).of(500)
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
    expect(result).to eq("test")
    expect(timings[:test1]).to be_within(0.5).of(1500)
    expect(timings[:test2]).to be_within(0.5).of(1000)
    expect(timings[:test3]).to be_within(0.5).of(500)
  end

  it '.in_realtime_block?' do
    expect(Benchmark.in_realtime_block?).to be_falsey
    Benchmark.realtime_block(:test1) do
      expect(Benchmark.in_realtime_block?).to be_truthy
    end
    expect(Benchmark.in_realtime_block?).to be_falsey
  end
end
