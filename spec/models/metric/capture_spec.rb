RSpec.describe Metric::Capture do
  include Spec::Support::MetricHelper

  before do
    MiqRegion.seed

    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".alert_capture_threshold" do
    let(:target) { FactoryBot.build(:host_vmware) }

    it "parses fixed num" do
      stub_performance_settings(:capture_threshold_with_alerts => {:host => 4})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.alert_capture_threshold(target)).to eq 4.minutes.ago.utc
      end
    end

    it "parses string" do
      stub_performance_settings(:capture_threshold_with_alerts => {:host => "4.minutes"})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.alert_capture_threshold(target)).to eq 4.minutes.ago.utc
      end
    end

    it "produces default with class not found" do
      stub_performance_settings(:capture_threshold_with_alerts => {:vm      => "4.minutes",
                                                                   :default => "1.minutes"})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.alert_capture_threshold(target)).to eq 1.minute.ago.utc
      end
    end
  end

  describe ".standard_capture_threshold" do
    let(:host) { FactoryBot.build(:host_vmware) }

    it "parses fixed num" do
      stub_performance_settings(:capture_threshold => {:host => 4})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.standard_capture_threshold(host)).to eq 4.minutes.ago.utc
      end
    end

    it "parses string" do
      stub_performance_settings(:capture_threshold => {:host => "4.minutes"})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.standard_capture_threshold(host)).to eq 4.minutes.ago.utc
      end
    end

    it "produces default with class not found" do
      stub_performance_settings(:capture_threshold => {:vm => "4.minutes", :default => "10.minutes"})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.standard_capture_threshold(host)).to eq 10.minutes.ago.utc
      end
    end
  end
end
