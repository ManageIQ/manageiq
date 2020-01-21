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
end
