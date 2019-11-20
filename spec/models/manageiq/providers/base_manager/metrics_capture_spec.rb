describe ManageIQ::Providers::BaseManager::MetricsCapture do
  include Spec::Support::MetricHelper

  subject { described_class.new(nil, ems) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems) { FactoryBot.create(:ems_vmware, :zone => miq_server.zone) }

  context ".perf_capture_health_check" do
    let(:vm) { FactoryBot.create(:vm_perf, :ext_management_system => ems) }
    let(:vm2) { FactoryBot.create(:vm_perf, :ext_management_system => ems) }

    it "should queue up realtime capture for vm" do
      subject.queue_captures([vm, vm2], {})
      expect(MiqQueue.count).to eq(2)

      expect(subject._log).to receive(:info).with(/2 "realtime" captures on the queue.*oldest:.*recent:/)
      expect(subject._log).to receive(:info).with(/0 "hourly" captures on the queue/)
      expect(subject._log).to receive(:info).with(/0 "historical" captures on the queue/)
      subject.send(:perf_capture_health_check)
    end
  end

  describe ".perf_capture_now" do
    context "with enabled and disabled targets" do
      before do
        MiqRegion.seed
        storages = FactoryBot.create_list(:storage_target_vmware, 2)
        @vmware_clusters = FactoryBot.create_list(:cluster_target, 2)
        ems.ems_clusters = @vmware_clusters

        6.times do |n|
          host = FactoryBot.create(:host_target_vmware, :ext_management_system => ems)
          ems.hosts << host

          @vmware_clusters[n / 2].hosts << host if n < 4
          host.storages << storages[n / 3]
        end

        MiqQueue.delete_all
      end

      context "executing perf_capture_gap" do
        before do
          t = Time.now.utc
          Metric::Capture.perf_capture_gap(t - 7.days, t - 5.days, nil, ems.id)
        end

        it "should queue up enabled targets for historical" do
          expect(MiqQueue.count).to eq(10)

          expected_targets = Metric::Targets.capture_ems_targets(ems.reload, :exclude_storages => true)
          expected = expected_targets.flat_map { |t| [[t, "historical"]] * 2 } # Vm, Host, Host, Vm, Host

          selected = queue_intervals(MiqQueue.all)

          expect(selected).to match_array(expected)
        end
      end
    end
  end

  describe ".perf_capture_now?" do
    before do
      stub_performance_settings(
        :capture_threshold_with_alerts => {:host => "2.minutes"},
        :capture_threshold             => {:host => "10.minutes"}
      )
    end

    let(:target) { FactoryBot.build(:host_vmware, :ext_management_system => ems) }

    context "with a host with alerts" do
      before do
        allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(true)
      end

      it "captures if the target has never been captured" do
        target.last_perf_capture_on = nil
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end

      it "does not capture if the target has been captured very recenlty" do
        target.last_perf_capture_on = 1.minute.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(false)
      end

      it "captures if the target has been captured recently (but after realtime minimum)" do
        target.last_perf_capture_on = 5.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end

      it "captures if the target hasn't been captured in a long while" do
        target.last_perf_capture_on = 15.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end
    end

    context "with an alertless host" do
      before do
        allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(false)
      end

      it "captures if the target has never been captured" do
        target.last_perf_capture_on = nil
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end

      it "does not captures if the target has been captured very recently" do
        target.last_perf_capture_on = 1.minute.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(false)
      end

      it "does not captures if the target has been captured recently (but after realtime minimum)" do
        target.last_perf_capture_on = 5.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(false)
      end

      it "captures if the target hasn't been captured in a long while" do
        target.last_perf_capture_on = 15.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end
    end
  end
end
