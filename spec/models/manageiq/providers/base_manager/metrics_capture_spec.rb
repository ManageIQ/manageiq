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
        clusters = FactoryBot.create_list(:cluster_target, 2)
        ems.ems_clusters = clusters

        6.times do |n|
          host = FactoryBot.create(:host_target_vmware, :ext_management_system => ems)
          ems.hosts << host

          clusters[n / 2].hosts << host if n < 4
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

          expect(queue_intervals).to match_array(expected)
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

  describe ".perf_capture_queue" do
    before do
      MiqRegion.seed
      @zone = miq_server.zone
    end

    let(:host) { FactoryBot.create(:host_target_vmware, :ext_management_system => ems).tap { MiqQueue.delete_all } }
    let(:vm) { host.vms.first }

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
        targets = Metric::Targets.capture_ems_targets(@ems_vmware.reload)
        expect(queue_intervals).to match_array(metric_targets(targets))
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
        @ems_openstack = FactoryBot.create(:ems_openstack, :zone => miq_server.zone)
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
          expect(queue_intervals).to match_array(metric_targets(expected_targets))
        end
      end
    end

    context "for queue prioritization" do
      it "should queue up realtime capture for vm" do
        vm.perf_capture_realtime_now
        expect(MiqQueue.count).to eq(1)

        msg = MiqQueue.first
        expect(msg.priority).to eq(MiqQueue::HIGH_PRIORITY)
        expect(msg.instance_id).to eq(vm.id)
        expect(msg.class_name).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
      end

      it "should raise the priority of the existing queue item" do
        vm.perf_capture_realtime_now
        MiqQueue.first.update_attribute(:priority, MiqQueue::NORMAL_PRIORITY)
        vm.perf_capture_realtime_now

        expect(MiqQueue.count).to eq(1)
        expect(MiqQueue.first.priority).to eq(MiqQueue::HIGH_PRIORITY)
      end

      it "should not lower the priority of the existing queue item" do
        vm.perf_capture_realtime_now
        MiqQueue.first.update_attribute(:priority, MiqQueue::MAX_PRIORITY)
        vm.perf_capture_realtime_now

        expect(MiqQueue.count).to eq(1)
        expect(MiqQueue.first.priority).to eq(MiqQueue::MAX_PRIORITY)
      end
    end
  end

  def trigger_capture(last_perf_capture_on = nil, options = {:interval => "realtime"})
    vm.last_perf_capture_on = last_perf_capture_on if last_perf_capture_on
    ems.perf_capture_object.queue_captures([vm], vm => options)
  end

  describe "#queue_items_for_interval" do
    let!(:ems) { FactoryBot.create(:ems_openstack, :zone => miq_server.zone) }
    let(:vm) { FactoryBot.create(:vm_perf_openstack, :ext_management_system => ems) }

    it "creates realtime only with last_perf_capture_on.nil? (first time) with no initial_capture" do
      stub_performance_settings(:history => {:initial_capture_days => nil})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime" => {vm => [[Time.now.utc.beginning_of_day]]}
        )

        Timecop.travel(20.minutes)
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime" => {vm => [[Time.now.utc.beginning_of_day]]}
        )
      end
    end

    it "creates realtime and historical with last_perf_capture_on.nil? (first time) with initial_capture" do
      stub_performance_settings(:history => {:initial_capture_days => 7})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime"   => {vm => [[Time.now.utc.beginning_of_day]]},
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )
      end
    end

    it "creates historical only when requesting historical and with last_perf_capture_on.nil? (first time) with initial_capture" do
      stub_performance_settings(:history => {:initial_capture_days => 7})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        trigger_capture(nil, :interval => "historical")
        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )

        Timecop.travel(20.minutes)
        trigger_capture(nil, :interval => "historical")

        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )
      end
    end

    it "creates realtime and historical with last_perf_capture_on older than the realtime_cut_off" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (10.days + 5.hours + 23.minutes).ago
        trigger_capture(last_perf_capture_on, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime"   => {vm => [[Time.now.utc.beginning_of_day]]},
          "historical" => {vm => arg_day_range(last_perf_capture_on, Time.now.utc.beginning_of_day)}
        )
      end
    end

    it "creates realtime only with last_perf_capture_on newer than the realtime_cut_off" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (2.hours + 5.minutes).ago
        trigger_capture(last_perf_capture_on, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime" => {vm => [[]]}
        )
      end
    end

    it "creates one set of realtime and historical with multiple calls" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (10.days + 5.hours + 23.minutes).ago
        trigger_capture(last_perf_capture_on, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime"   => {vm => [[Time.now.utc.beginning_of_day]]},
          "historical" => {vm => arg_day_range(last_perf_capture_on, Time.now.utc.beginning_of_day)}
        )

        Timecop.travel(20.minutes)
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime"   => {vm => [[Time.now.utc.beginning_of_day]]},
          "historical" => {vm => arg_day_range(last_perf_capture_on, Time.now.utc.beginning_of_day)}
        )
      end
    end

    it "creates queue item with task_id (which will set MiqTask#started_on)" do
      MiqQueue.delete_all
      task = FactoryBot.create(:miq_task)
      trigger_capture(nil, :interval => "realtime", :task_id => task.id)

      expect(MiqQueue.first.miq_task_id).to eq task.id
    end

    it "creates historical only when requesting historical and with old last_perf_capture_on with initial_capture" do
      stub_performance_settings(:history => {:initial_capture_days => 7})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (10.days + 5.hours + 23.minutes).ago
        trigger_capture(last_perf_capture_on, :interval => "historical")
        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )

        Timecop.travel(20.minutes)
        trigger_capture(last_perf_capture_on, :interval => "historical")

        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )
      end
    end

    it "creates historical only when requesting historical and recent last_perf_capture_on with initial_capture" do
      stub_performance_settings(:history => {:initial_capture_days => 7})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (2.days + 5.hours + 23.minutes).ago
        trigger_capture(last_perf_capture_on, :interval => "historical")
        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )

        Timecop.travel(20.minutes)
        trigger_capture(last_perf_capture_on, :interval => "historical")

        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(7.days.ago.utc.beginning_of_day, 1.day.from_now.utc.beginning_of_day)}
        )
      end
    end

    it "creates historical only when requesting historical with dates with recent last_perf_capture_on" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (2.days + 5.hours + 23.minutes).ago
        trigger_capture(last_perf_capture_on, :interval => "historical", :start_time => 4.days.ago.utc, :end_time => 2.days.ago.utc)
        expect(queue_timings).to eq(
          "historical" => {vm => arg_day_range(4.days.ago.utc, 2.days.ago.utc)}
        )
      end
    end
  end
end
