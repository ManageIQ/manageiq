RSpec.describe Metric::Capture do
  include Spec::Support::MetricHelper

  before do
    Zone.seed
    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".perf_capture_timer" do
    let(:ems) { FactoryBot.create(:ext_management_system) }

    before { allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems) }

    it "calls perf_capture_all_queue" do
      expect(ems).to receive_message_chain(:perf_capture_object, :perf_capture_all_queue)
      described_class.perf_capture_timer(ems.id)
    end

    context "with a paused EMS" do
      let(:ems) { FactoryBot.create(:ext_management_system, :zone => Zone.maintenance_zone, :enabled => false) }

      it "doesn't call perf_capture_all_queue" do
        expect(ems).not_to receive(:perf_capture_object)
        described_class.perf_capture_timer(ems.id)
      end
    end
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
