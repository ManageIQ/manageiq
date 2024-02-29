RSpec.describe VimPerformanceTagValue do
  include Spec::Support::ChargebackHelper

  context "#get_metrics" do
    let(:ts) { Time.zone.now }
    let(:category) { [] }
    let(:resources) { [] }
    let(:vim_performance_daily) { false }

    it "handles 'realtime' interval" do
      interval = 'realtime'
      metrics = VimPerformanceTagValue.send(:get_metrics, resources, ts, interval, vim_performance_daily, category)
      expect(metrics).to be_empty
    end

    it "handles 'hourly' interval" do
      interval = 'hourly'
      metrics = VimPerformanceTagValue.send(:get_metrics, resources, ts, interval, vim_performance_daily, category)
      expect(metrics).to be_empty
    end

    it "handles VimPerformanceDaily type" do
      interval = nil
      vim_performance_daily = true
      metrics = VimPerformanceTagValue.send(:get_metrics, resources, ts, interval, vim_performance_daily, category)
      expect(metrics).to be_empty
    end

    context "with metrics and a category" do
      let(:development_vm) { FactoryBot.create(:vm_vmware, :created_on => report_run_time) }

      let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
      let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(:tz => 'UTC')) }
      let(:report_run_time) { ts.end_of_month.utc }

      let(:start_time)  { report_run_time - 17.hours }
      let(:finish_time) { report_run_time - 14.hours }

      before do
        metric_rollup_params = {:tag_names => "environment/dev"}
        add_metric_rollups_for(development_vm, start_time...finish_time, 1.hour, metric_rollup_params)
      end

      it "finds metrics" do
        interval = nil
        vim_performance_daily = true
        metrics = VimPerformanceTagValue.send(:get_metrics, [development_vm], start_time, interval, vim_performance_daily, "environment")
        expect(metrics).not_to be_empty
      end
    end
  end
end
