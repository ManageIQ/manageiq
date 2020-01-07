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

  describe ".perf_capture_gap" do
    before do
      MiqRegion.seed
    end

    let(:host) { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true) }
    let!(:vm)   { FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host) }
    let(:host2) do
      FactoryBot.create(
        :host_vmware,
        :ext_management_system => ems,
        :perf_capture_enabled  => true,
        :storages              => [storage],
        :ems_cluster           => FactoryBot.create(:ems_cluster, :perf_capture_enabled => true, :ext_management_system => ems)
      )
    end
    let!(:vm2)     { FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host2) }
    let!(:host3)   { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true) }
    let(:storage) { FactoryBot.create(:storage_vmware, :perf_capture_enabled => true) }

    it "should queue up targets for historical" do
      Timecop.freeze do
        Metric::Capture.perf_capture_gap(7.days.ago.utc, 5.days.ago.utc, nil, ems.id)
        expect(queue_timings).to eq(
          "historical" => {
            vm    => arg_day_range(7.days.ago.utc, 5.days.ago.utc),
            vm2   => arg_day_range(7.days.ago.utc, 5.days.ago.utc),
            host  => arg_day_range(7.days.ago.utc, 5.days.ago.utc),
            host2 => arg_day_range(7.days.ago.utc, 5.days.ago.utc),
            host3 => arg_day_range(7.days.ago.utc, 5.days.ago.utc),
          }
        )
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
    end

    let(:host) { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true) }
    let(:vm)   { FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host).tap { MiqQueue.delete_all } }
    let(:host2) do
      FactoryBot.create(
        :host_vmware,
        :ext_management_system => ems,
        :perf_capture_enabled  => true,
        :storages              => [storage],
        :ems_cluster           => FactoryBot.create(:ems_cluster, :perf_capture_enabled => true, :ext_management_system => ems)
      )
    end
    let(:vm2)     { FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host2) }
    let(:host3)   { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true) }
    let(:storage) { FactoryBot.create(:storage_vmware, :perf_capture_enabled => true) }

    context "with vmware targets" do
      it "should queue up targets properly" do
        stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
        ems.perf_capture_object.queue_captures([vm, vm2, storage, host, host2, host3], {})

        bod = Time.now.utc.beginning_of_day

        expect(queue_timings).to eq(
          "realtime"   => {
            host  => [[4.hours.ago.utc.beginning_of_day]],
            host2 => [[4.hours.ago.utc.beginning_of_day]],
            host3 => [[4.hours.ago.utc.beginning_of_day]],
            vm    => [[4.hours.ago.utc.beginning_of_day]],
            vm2   => [[4.hours.ago.utc.beginning_of_day]]
          },
          "historical" => {
            host  => arg_day_range(bod - 7.days, bod + 1.day),
            host2 => arg_day_range(bod - 7.days, bod + 1.day),
            host3 => arg_day_range(bod - 7.days, bod + 1.day),
            vm    => arg_day_range(bod - 7.days, bod + 1.day),
            vm2   => arg_day_range(bod - 7.days, bod + 1.day)
          },
          "hourly"     => {
            storage => [[4.hours.ago.utc.beginning_of_day]]
          }
        )
      end

      it "calling perf_capture_timer when existing capture messages are on the queue in dequeue state should NOT merge" do
        ems.perf_capture_object.queue_captures([vm, vm2, storage, host, host2, host3], {})
        messages = MiqQueue.where(:class_name => "Host", :method_name => 'capture_metrics_realtime')
        messages.each { |m| m.update(:state => "dequeue") }

        ems.perf_capture_object.queue_captures([vm, vm2, storage, host, host2, host3], {})
        messages = MiqQueue.where(:class_name => "Host", :method_name => 'capture_metrics_realtime')
        messages.each { |m| expect(m.lock_version).to eq(1) }
      end
    end

    context "with enabled and disabled openstack targets" do
      let(:ems) { FactoryBot.create(:ems_openstack, :zone => miq_server.zone) }
      let(:vms) { FactoryBot.create_list(:vm_openstack, 3, :ext_management_system => ems) }

      context "executing perf_capture_timer" do
        it "should queue up enabled targets" do
          stub_settings(:performance => {:history => {:initial_capture_days => 7}})
          ems.perf_capture_object.queue_captures(vms, {})

          bod = Time.now.utc.beginning_of_day

          expect(queue_timings).to eq(
            "realtime"   => vms.each_with_object({}) { |k, h| h[k] = [[4.hours.ago.utc.beginning_of_day]] },
            "historical" => vms.each_with_object({}) { |k, h| h[k] = arg_day_range(bod - 7.days, bod + 1.day) }
          )
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
          "realtime" => {vm => [[4.hours.ago.utc.beginning_of_day]]}
        )

        Timecop.travel(20.minutes)
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime" => {vm => [[4.hours.ago.utc.beginning_of_day]]}
        )
      end
    end

    it "creates realtime and historical with last_perf_capture_on.nil? (first time) with initial_capture" do
      stub_performance_settings(:history => {:initial_capture_days => 7})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime"   => {vm => [[4.hours.ago.utc.beginning_of_day]]},
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
          "realtime"   => {vm => [[4.hours.ago.utc.beginning_of_day]]},
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
          "realtime"   => {vm => [[4.hours.ago.utc.beginning_of_day]]},
          "historical" => {vm => arg_day_range(last_perf_capture_on, Time.now.utc.beginning_of_day)}
        )

        Timecop.travel(20.minutes)
        trigger_capture(nil, :interval => "realtime")

        expect(queue_timings).to eq(
          "realtime"   => {vm => [[4.hours.ago.utc.beginning_of_day]]},
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
