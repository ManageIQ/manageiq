describe Metric::Capture do
  describe ".alert_capture_threshold" do
    let(:target) { FactoryGirl.build(:host_vmware) }

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
    let(:host) { FactoryGirl.build(:host_vmware) }

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
      stub_performance_settings(:capture_threshold => {:vm      => "4.minutes",
                                                       :default => "10.minutes"})
      Timecop.freeze(Time.now.utc) do
        expect(described_class.standard_capture_threshold(host)).to eq 10.minutes.ago.utc
      end
    end
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
      described_class.send(:perf_capture_health_check, miq_server.zone)
    end
  end

  describe ".perf_capture_now?" do
    before do
      stub_performance_settings(
        :capture_threshold_with_alerts => {:host => "2.minutes"},
        :capture_threshold             => {:host => "10.minutes"}
      )
    end

    let(:target) { FactoryGirl.build(:host_vmware) }

    context "with a host with alerts" do
      before do
        allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(true)
      end

      it "captures if the target has never been captured" do
        target.last_perf_capture_on = nil
        expect(described_class.perf_capture_now?(target)).to eq(true)
      end

      it "does not capture if the target has been captured very recenlty" do
        target.last_perf_capture_on = 1.minute.ago
        expect(described_class.perf_capture_now?(target)).to eq(false)
      end

      it "captures if the target has been captured recently (but after realtime minimum)" do
        target.last_perf_capture_on = 5.minutes.ago
        expect(described_class.perf_capture_now?(target)).to eq(true)
      end

      it "captures if the target hasn't been captured in a long while" do
        target.last_perf_capture_on = 15.minutes.ago
        expect(described_class.perf_capture_now?(target)).to eq(true)
      end
    end

    context "with an alertless host" do
      before do
        allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(false)
      end

      it "captures if the target has never been captured" do
        target.last_perf_capture_on = nil
        expect(described_class.perf_capture_now?(target)).to eq(true)
      end

      it "does not captures if the target has been captured very recently" do
        target.last_perf_capture_on = 1.minute.ago
        expect(described_class.perf_capture_now?(target)).to eq(false)
      end

      it "does not captures if the target has been captured recently (but after realtime minimum)" do
        target.last_perf_capture_on = 5.minutes.ago
        expect(described_class.perf_capture_now?(target)).to eq(false)
      end

      it "captures if the target hasn't been captured in a long while" do
        target.last_perf_capture_on = 15.minutes.ago
        expect(described_class.perf_capture_now?(target)).to eq(true)
      end
    end
  end

  def stub_performance_settings(hash)
    stub_settings(:performance => hash)
  end
end
