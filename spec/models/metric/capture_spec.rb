describe Metric::Capture do
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

  describe ".perf_capture_timer" do
    context "with enabled and disabled vmware targets", :with_enabled_disabled_vmware do
      let(:expected_queue_items) do
        {
          %w[ManageIQ::Providers::Vmware::InfraManager::Host perf_capture_realtime]   => 3,
          %w[ManageIQ::Providers::Vmware::InfraManager::Host perf_capture_historical] => 24,
          %w[Storage perf_capture_hourly]                                             => 1,
          %w[ManageIQ::Providers::Vmware::InfraManager::Vm perf_capture_realtime]     => 2,
          %w[ManageIQ::Providers::Vmware::InfraManager::Vm perf_capture_historical]   => 16,
          %w[MiqTask destroy_older_by_condition]                                      => 1
        }
      end

      it "should queue up enabled targets" do
        stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
        Metric::Capture.perf_capture_timer(@ems_vmware.id)

        expect(MiqQueue.group(:class_name, :method_name).count).to eq(expected_queue_items)
        assert_metric_targets(Metric::Targets.capture_ems_targets(@ems_vmware.reload))
      end

      it "calling perf_capture_timer when existing capture messages are on the queue in dequeue state should NOT merge" do
        Metric::Capture.perf_capture_timer(@ems_vmware.id)
        messages = MiqQueue.where(:class_name => "Host", :method_name => 'capture_metrics_realtime')
        messages.each { |m| m.update_attribute(:state, "dequeue") }

        Metric::Capture.perf_capture_timer(@ems_vmware.id)

        messages = MiqQueue.where(:class_name => "Host", :method_name => 'capture_metrics_realtime')
        messages.each { |m| expect(m.lock_version).to eq(1) }
      end
    end

    context "with enabled and disabled openstack targets" do
      before do
        @ems_openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
        @availability_zone = FactoryBot.create(:availability_zone_target)
        @ems_openstack.availability_zones << @availability_zone
        @vms_in_az = FactoryBot.create_list(:vm_openstack, 2, :ems_id => @ems_openstack.id)
        @availability_zone.vms = @vms_in_az
        @availability_zone.vms.push(FactoryBot.create(:vm_openstack, :ems_id => nil))
        @vms_not_in_az = FactoryBot.create_list(:vm_openstack, 3, :ems_id => @ems_openstack.id)

        MiqQueue.delete_all
      end

      context "executing perf_capture_timer" do
        before do
          stub_settings(:performance => {:history => {:initial_capture_days => 7}})
          Metric::Capture.perf_capture_timer(@ems_openstack.id)
        end

        it "should queue up enabled targets" do
          expected_targets = Metric::Targets.capture_ems_targets(@ems_openstack)
          expect(MiqQueue.group(:method_name).count).to eq('perf_capture_realtime'      => expected_targets.count,
                                                           'perf_capture_historical'    => expected_targets.count * 8,
                                                           'destroy_older_by_condition' => 1)
          assert_metric_targets(expected_targets)
        end
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

  context ".perf_capture_health_check" do
    let(:miq_server) { EvmSpecHelper.local_miq_server }
    let(:ems) { FactoryBot.create(:ems_vmware, :zone => miq_server.zone) }
    let(:vm) { FactoryBot.create(:vm_perf, :ext_management_system => ems) }
    let(:vm2) { FactoryBot.create(:vm_perf, :ext_management_system => ems) }

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

  describe ".perf_capture_now" do
    context "with enabled and disabled targets" do
      before do
        @ems_vmware = FactoryBot.create(:ems_vmware, :zone => @zone)
        storages = FactoryBot.create_list(:storage_target_vmware, 2)
        @vmware_clusters = FactoryBot.create_list(:cluster_target, 2)
        @ems_vmware.ems_clusters = @vmware_clusters

        6.times do |n|
          host = FactoryBot.create(:host_target_vmware, :ext_management_system => @ems_vmware)
          @ems_vmware.hosts << host

          @vmware_clusters[n / 2].hosts << host if n < 4
          host.storages << storages[n / 3]
        end

        MiqQueue.delete_all
      end

      context "executing perf_capture_gap" do
        before do
          t = Time.now.utc
          Metric::Capture.perf_capture_gap(t - 7.days, t - 5.days)
        end

        it "should queue up enabled targets for historical" do
          expect(MiqQueue.count).to eq(10)

          expected_targets = Metric::Targets.capture_ems_targets(@ems_vmware.reload, :exclude_storages => true)
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

    let(:target) { FactoryBot.build(:host_vmware) }

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

  private

  def stub_performance_settings(hash)
    stub_settings(:performance => hash)
  end
end
