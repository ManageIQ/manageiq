describe Metric::Capture do
  shared_examples "captures a threshold" do |capture_fixnum, capture|
    let(:threshold_default) { 10 }
    let(:capture_rt) { 2 }
    let(:time) { Time.utc(2013, 4, 22, 8, 31) }

    before do
      settings =  {:performance =>
                    {:capture_threshold             => {:vm => capture,    :host => capture},
                     :capture_threshold_with_alerts => {:vm => capture_rt, :host => capture_rt}
                    }
                  }
      stub_server_configuration(settings)
    end

    it "realtime vm uses capture_threshold_with_alerts minutes ago" do
      target = FactoryGirl.build(:vm_vmware)
      allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(true)

      Timecop.freeze(time) do
        expect(described_class.capture_threshold(target)).to eq capture_rt.minutes.ago.utc
      end
    end

    it "realtime host uses capture_threshold_with_alerts minutes ago" do
      target = FactoryGirl.build(:host_vmware)
      allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(true)

      Timecop.freeze(time) do
        expect(described_class.capture_threshold(target)).to eq capture_rt.minutes.ago.utc
      end
    end

    it "non-realtime vm uses capture_threshold minutes ago" do
      target = FactoryGirl.build(:vm_vmware)
      allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(false)

      Timecop.freeze(time) do
        result = threshold_default.minutes.ago.utc
        result = capture_fixnum.minutes.ago.utc unless capture_fixnum.nil?
        expect(described_class.capture_threshold(target)).to eq result
      end
    end

    it "non-realtime host uses capture_threshold minutes ago" do
      target = FactoryGirl.build(:host_vmware)
      allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(false)

      Timecop.freeze(time) do
        result = threshold_default.minutes.ago.utc
        result = capture_fixnum.minutes.ago.utc unless capture_fixnum.nil?
        expect(described_class.capture_threshold(target)).to eq result
      end
    end
  end

  context ".capture_threshold with Fixnum" do
    include_examples "captures a threshold", 20, 20
  end

  context ".capture_threshold with String" do
    include_examples "captures a threshold", 50, "50.minutes"
  end

  context ".capture_threshold handles nil" do
    include_examples "captures a threshold", nil, nil
  end

  context ".perf_capture_health_check" do
    let(:miq_server) { EvmSpecHelper.local_miq_server }
    let(:ems) { FactoryGirl.create(:ems_vmware, :zone => miq_server.zone) }
    let(:vm) { FactoryGirl.create(:vm_perf, :ext_management_system => ems) }
    let(:vm2) { FactoryGirl.create(:vm_perf, :ext_management_system => ems) }

    it "should queue up realtime capture for vm" do
      vm.perf_capture_realtime_now
      vm2.perf_capture_realtime_now
      expect(MiqQueue.count).to eq(2)

      expect(Metric::Capture._log).to receive(:info).with(/2 "realtime" captures on the queue.*oldest:.*recent:/)
      expect(Metric::Capture._log).to receive(:info).with(/0 "hourly" captures on the queue/)
      expect(Metric::Capture._log).to receive(:info).with(/0 "historical" captures on the queue/)
      described_class.perf_capture_health_check(miq_server.zone)
    end
  end
end
