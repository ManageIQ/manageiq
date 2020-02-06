RSpec.describe VimPerformanceTagValue do
  context "#get_metrics" do
    let(:ts) { Time.zone.now }
    let(:category) { [] }
    let(:resources) { [] }
    let(:vim_performance_daily) { false }

    it "handles 'realtime' interval" do
      interval = 'realtime'
      metrics = VimPerformanceTagValue.send('get_metrics', resources, ts, interval, vim_performance_daily, category)
      expect(metrics).to be_empty
    end

    it "handles 'hourly' interval" do
      interval = 'hourly'
      metrics = VimPerformanceTagValue.send('get_metrics', resources, ts, interval, vim_performance_daily, category)
      expect(metrics).to be_empty
    end

    it "handles VimPerformanceDaily type" do
      interval = nil
      vim_performance_daily = true
      metrics = VimPerformanceTagValue.send('get_metrics', resources, ts, interval, vim_performance_daily, category)
      expect(metrics).to be_empty
    end
  end
end
