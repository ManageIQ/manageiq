RSpec.describe MiqAlert do
  context "With single server with a single generic worker with the notifier role," do
    before do
      @miq_server = EvmSpecHelper.local_miq_server(:role => 'notifier')
      @worker = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id)
      @vm     = FactoryBot.create(:vm_vmware)

      MiqAlert.seed
      @events_to_alerts = MiqAlert.all.inject([]) do |arr, a|
        next(arr) if a.responds_to_events.nil?
        next(arr) unless a.db == "Vm"

        ap = FactoryBot.create(:miq_alert_set_vm, :alerts => [a])
        ap.assign_to_objects(@vm)

        events = a.responds_to_events.split(",")
        events.each do |e|
          event = e.strip
          arr << [event, a.guid]
        end
        arr
      end
    end

    context "where a vm_scan_complete event is raised for a VM" do
      before do
        MiqAlert.all.each { |a| a.update_attribute(:enabled, true) } # enable out of the box alerts
        MiqAlert.evaluate_alerts(@vm, "vm_scan_complete")
      end

      it "should alert 'VM Guest Windows Event Log Error - NtpClient' should be evaluated" do
        msg = MiqQueue.get(:role => "notifier")
        expect(msg).not_to be_nil

        alert = MiqAlert.find_by(:id => msg.instance_id)
        expect(alert).not_to be_nil
        expect(alert.description).to eq('VM Guest Windows Event Log Error - NtpClient')
      end
    end

    context "where a vm_scan_complete event is raised for a VM" do
      before do
        MiqAlert.all.each { |a| a.update_attribute(:enabled, true) } # enable out of the box alerts
        @events_to_alerts.each do |arr|
          MiqAlert.evaluate_alerts([@vm.class.base_class.name, @vm.id], arr.first)
        end
      end

      it "should queue up the correct alert for each event" do
        guids = @events_to_alerts.collect(&:last).uniq
        messages = MiqQueue.order("id")
        expect(messages.length).to eq(@events_to_alerts.length)

        messages.each_with_index do |msg, i|
          alert = MiqAlert.find_by(:id => msg.instance_id)
          expect(alert).not_to be_nil

          expect(guids.include?(alert.guid)).to be_truthy
        end
      end
    end

    context "where all alerts are disabled" do
      before do
        MiqAlert.all.each { |a| a.update_attribute(:enabled, false) }
        MiqAlert.evaluate_alerts([@vm.class.base_class.name, @vm.id], "vm_scan_complete")
      end

      it "should not evaluate any alerts" do
        @msg = MiqQueue.get(:role => "notifier")
        expect(@msg).to be_nil
      end
    end

    context "with a single alert, not evaluated" do
      before do
        @alert = MiqAlert.find_by(:description => "VM Unregistered")
      end

      context "with a delay_next_evaluation value of 5 minutes" do
        before do
          @alert.options ||= {}
          @alert.options.store_path(:notifications, :delay_next_evaluation, 5.minutes)
        end

        it "should always perform evaluation if not previously evaluated (after 4 minutes)" do
          Timecop.travel 4.minutes do
            expect(@alert.postpone_evaluation?(@vm)).to be_falsey
          end
        end
      end
    end

    context "with a single alert, evaluated to true" do
      before do
        @alert = MiqAlert.find_by(:description => "VM Unregistered")
        allow(@alert).to receive_messages(:eval_expression => true)
      end

      it "should have a link from the MiqAlert to the miq alert status" do
        @alert.evaluate([@vm.class.base_class.name, @vm.id])
        expect(@alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).count).to eq(1)
      end

      it "should have a miq alert status for MiqAlert with a result of true" do
        @alert.evaluate([@vm.class.base_class.name, @vm.id])
        expect(@alert.miq_alert_statuses.find_by(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).result).to be_truthy
      end

      it "should update the existing status on susesquent evaluations" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event)
        )
        Timecop.travel 10.minutes do
          @alert.evaluate(
            [@vm.class.base_class.name, @vm.id],
            :ems_event => FactoryBot.create(:ems_event)
          )
          statuses = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id)
          expect(statuses.length).to eq(1)
        end
      end

      it "should update the existing status if event has the same ems_ref" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :ems_ref => 'same')
        )
        Timecop.travel 10.minutes do
          @alert.evaluate(
            [@vm.class.base_class.name, @vm.id],
            :ems_event => FactoryBot.create(:ems_event, :ems_ref => 'same')
          )
          statuses = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id)
          expect(statuses.length).to eq(1)
        end
      end

      it "should create a new status if event has a different ems_ref" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :ems_ref => 'same')
        )
        Timecop.travel 10.minutes do
          @alert.evaluate(
            [@vm.class.base_class.name, @vm.id],
            :ems_event => FactoryBot.create(:ems_event, :ems_ref => 'different')
          )
          statuses = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id)
          expect(statuses.length).to eq(2)
        end
      end

      it "does not explode if evaluate.input = {}" do
        expect { @alert.evaluate([@vm.class.base_class.name, @vm.id]) }.to_not raise_error
      end

      it "miq_alert_status.description = miq_alert.description event if overriden by ems_event.description" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :message => "oh no!")
        )
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.description).to eq("VM Unregistered")
      end

      it "miq_alert_status.description = ems_event.message if present and datawarehouse_alert" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :message => "oh no!", :event_type => "datawarehouse_alert")
        )
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.description).to eq("oh no!")
      end

      it "miq_alert_status.severity = ems_event.full_data.severity if present" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :full_data => {:severity => 'warning'})
        )
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.severity).to eq('warning')
      end

      it "miq_alert_status.severity = MiqAlert#severity if ems_event.full_data.severity not present" do
        @alert.severity = "error"
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :full_data => {})
        )
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.severity).to eq('error')
      end

      it "miq_alert_status.severity = ems_event.full_data.severity  if present and MiqAlert#severity is also present" do
        @alert.severity = "error"
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(:ems_event, :full_data => {:severity => 'info'})
        )
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.severity).to eq('info')
      end

      it "miq_alert_status.severity = nil if  ems_event.full_data.severity not present" do
        @alert.evaluate([@vm.class.base_class.name, @vm.id])
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.severity).to eq(nil)
      end

      it "raises an exception when miq_alert_status creation fails" do
        expect do
          @alert.evaluate(
            [@vm.class.base_class.name, @vm.id],
            :ems_event => FactoryBot.create(:ems_event, :full_data => {:severity => 'undefined'})
          )
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "miq_alert_status.url = ems_event.full_data.url if present" do
        @alert.evaluate(
          [@vm.class.base_class.name, @vm.id],
          :ems_event => FactoryBot.create(
            :ems_event,
            :full_data => {:url => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'}
          )
        )
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.url).to eq('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
      end

      it "miq_alert_status.url = nil if ems_event.full_data.url is not present" do
        @alert.evaluate([@vm.class.base_class.name, @vm.id])
        mas = @alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).first
        expect(mas.url).to eq(nil)
      end

      it "should have a link from the Vm to the miq alert status" do
        @alert.evaluate([@vm.class.base_class.name, @vm.id])
        expect(@vm.miq_alert_statuses.where(:miq_alert_id => @alert.id).count).to eq(1)
      end

      it "should have a miq alert status for Vm with a result of true" do
        @alert.evaluate([@vm.class.base_class.name, @vm.id])
        expect(@vm.miq_alert_statuses.find_by(:miq_alert_id => @alert.id).result).to be_truthy
      end

      context "with the alert now evaluated to false" do
        before do
          @alert.evaluate([@vm.class.base_class.name, @vm.id])
          allow(@alert).to receive_messages(:eval_expression => false)
          @alert.options.store_path(:notifications, :delay_next_evaluation, 0)
          @alert.evaluate([@vm.class.base_class.name, @vm.id])
        end

        it "should have had the MiqAlert's miq_alert_statuses" do
          expect(@alert.miq_alert_statuses.where(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).count).to eq(1)
        end

        it "should have a miq alert status for MiqAlert with a result of false" do
          expect(@alert.miq_alert_statuses.find_by(:resource_type => @vm.class.base_class.name, :resource_id => @vm.id).result).to be_falsey
        end

        it "should have the Vm's miq_alert_statuses" do
          expect(@vm.miq_alert_statuses.where(:miq_alert_id => @alert.id).count).to eq(1)
        end

        it "should have a miq alert status for Vm with a result of false" do
          expect(@vm.miq_alert_statuses.find_by(:miq_alert_id => @alert.id).result).to be_falsey
        end
      end

      context "with a delay_next_evaluation value of 5 minutes" do
        before do
          @alert.evaluate([@vm.class.base_class.name, @vm.id])
          @alert.options ||= {}
          @alert.options.store_path(:notifications, :delay_next_evaluation, 5.minutes)
          @alert.save
        end

        it "should retry evaluation (after 10 minutes)" do
          Timecop.travel 10.minutes do
            expect(@alert.postpone_evaluation?(@vm)).to be_falsey
          end
        end

        it "should skip evaluation (after 4 minutes)" do
          Timecop.travel 4.minutes do
            expect(@alert.postpone_evaluation?(@vm)).to be_truthy
          end
        end
      end
    end

    context "where all alerts are unassigned" do
      before do
        @original_assigned     = MiqAlert.assigned_to_target(@vm, "vm_perf_complete") # force cache load
        @original_assigned_all = MiqAlert.assigned_to_target(@vm)                     # force cache load
        MiqAlertSet.all.each(&:remove_all_assigned_tos)

        @assigned_now     = MiqAlert.assigned_to_target(@vm, "vm_perf_complete")
        @assigned_all_now = MiqAlert.assigned_to_target(@vm)

        Timecop.travel(6.minutes) do
          @assigned_later     = MiqAlert.assigned_to_target(@vm, "vm_perf_complete")
          @assigned_all_later = MiqAlert.assigned_to_target(@vm)
        end
      end

      it "should still have alerts assigned to vm now" do
        expect(@assigned_now.length).to eq(@original_assigned.length)
        expect(@assigned_all_now.length).to eq(@original_assigned_all.length)
      end

      it "should not have any alerts assigned to vm later" do
        expect(@assigned_later.length).to eq(0)
        expect(@assigned_all_later.length).to eq(0)
      end
    end
  end

  describe ".assigned_to_target" do
    it "gets assignment by tagged VM" do
      cat = FactoryBot.create(:classification, :description => "Environment", :name => "environment", :single_value => true)
      FactoryBot.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)

      @vm   = FactoryBot.create(:vm_vmware)
      @mode = @vm.class.base_model.name
      @c    = Classification.where(:description => "Production").first
      @c.assign_entry_to(@vm)

      @alert = FactoryBot.create(:miq_alert_vm)
      @ap    = FactoryBot.create(:miq_alert_set_vm, :alerts =>[@alert])
      @ap.assign_to_tags([@c.id], @mode)

      expect(MiqAlert.assigned_to_target(@vm)).to eq([@alert])
    end
  end

  context ".target_needs_realtime_capture?" do
    before do
      allow_any_instance_of(MiqAlert).to receive_messages(:validate => true)
    end

    let(:vm_alert_set) do
      alert = FactoryBot.create(:miq_alert_vm, :responds_to_events => "xxx|vm_perf_complete|zzz")
      FactoryBot.create(:miq_alert_set_vm, :alerts => [alert])
    end

    let(:host_alert_set) do
      alert = FactoryBot.create(:miq_alert_host, :responds_to_events => "xxx|host_perf_complete|zzz")
      FactoryBot.create(:miq_alert_set_host, :alerts => [alert])
    end

    it "detects true with a VM assigned to a realtime C&U alert" do
      vm = FactoryBot.create(:vm_vmware)
      vm_alert_set.assign_to_objects(vm)

      expect(MiqAlert.target_needs_realtime_capture?(vm)).to be_truthy
    end

    it "detects false with a VM NOT assigned to a realtime C&U alert" do
      vm = FactoryBot.create(:vm_vmware)

      expect(MiqAlert.target_needs_realtime_capture?(vm)).to be_falsey
    end

    it "detects true with a VM's ems assigned to a realtime C&U alert" do
      allow_any_instance_of(MiqAlert).to receive_messages(:validate => true)

      ems = FactoryBot.create(:ems_vmware)
      vm = FactoryBot.create(:vm_vmware, :ext_management_system => ems)
      vm_alert_set.assign_to_objects(ems)

      expect(MiqAlert.target_needs_realtime_capture?(vm)).to be_truthy
    end

    it "detects true with a Host assigned to a realtime C&U alert" do
      host = FactoryBot.create(:host)
      host_alert_set.assign_to_objects(host)

      expect(MiqAlert.target_needs_realtime_capture?(host)).to be_truthy
    end

    it "detects true with a Host's cluster assigned to a realtime C&U alert" do
      cluster = FactoryBot.create(:ems_cluster)
      host = FactoryBot.create(:host, :ems_cluster => cluster)
      host_alert_set.assign_to_objects(cluster)

      expect(MiqAlert.target_needs_realtime_capture?(host)).to be_truthy
    end

    it "detects false with a Host NOT assigned to a realtime C&U alert" do
      host = FactoryBot.create(:host)

      expect(MiqAlert.target_needs_realtime_capture?(host)).to be_falsey
    end

    it "detects true with a VM assigned to a v4-style realtime C&U alert" do
      vm = FactoryBot.create(:vm_vmware)
      # V4 code is actually the same here -- assign_to_objects -- but
      # this forces the namespace to use actual model class name
      # rather than base_class
      vm_alert_set.assign_to_objects(vm.id, "Vm")

      expect(MiqAlert.target_needs_realtime_capture?(vm)).to be_truthy
    end

    it "detects true with a Host assigned to a v4-style realtime C&U alert" do
      host = FactoryBot.create(:host)
      # V4 code is actually the same here -- assign_to_objects -- but
      # this forces the namespace to use actual model class name
      # rather than base_class
      host_alert_set.assign_to_objects(host.id, "Host")

      expect(MiqAlert.target_needs_realtime_capture?(host)).to be_truthy
    end

    let(:classification) do
      env = FactoryBot.create(:classification, :name => "env", :single_value => 1)
      FactoryBot.create(:classification_tag, :name => "good", :parent => env)
    end

    let(:tag) { classification.tag }

    it "detects with a shared tag on a Vm" do
      vm = FactoryBot.create(:vm_vmware)
      vm.tag_add(tag.name, :ns => "")
      vm.reload # reload ensures the tag is set

      vm_alert_set.assign_to_tags([classification.id], "vm")
      vm_alert_set.reload # reload ensures the tag is set

      expect(MiqAlert.target_needs_realtime_capture?(vm)).to be_truthy
    end

    it "does not detect with a shared tag assigned to a Vm's ems" do
      ems = FactoryBot.create(:ems_vmware)
      vm = FactoryBot.create(:vm_vmware, :ext_management_system => ems)
      ems.tag_add(tag.name, :ns => "")
      ems.reload # reload ensures the tag is set

      vm_alert_set.assign_to_tags([classification.id], "ext_management_system")
      vm_alert_set.reload # reload ensures the tag is set

      expect(MiqAlert.target_needs_realtime_capture?(vm)).to be_truthy
    end
  end

  context ".evaluate_hourly_timer" do
    before do
      allow_any_instance_of(MiqAlert).to receive_messages(:validate => true)
      @miq_server = EvmSpecHelper.local_miq_server
      @ems        = FactoryBot.create(:ems_vmware, :zone => @miq_server.zone)
      @ems_other  = FactoryBot.create(:ems_vmware, :zone => FactoryBot.create(:zone, :name => 'other'))
      @ems_kub    = FactoryBot.create(:ems_kubernetes, :zone => @miq_server.zone)
      @alert      = FactoryBot.create(:miq_alert, :responds_to_events => "_hourly_timer_")
      @alert_prof = FactoryBot.create(:miq_alert_set, :alerts => [@alert])
    end

    it "evaluates for ext_management_system" do
      @alert.update(:db => "ExtManagementSystem")
      @alert_prof.mode = @ems.class.base_model.name
      @alert_prof.assign_to_objects(@ems.id, "ExtManagementSystem")

      expect(MiqAlert).to receive(:evaluate_alerts).with(@ems, "_hourly_timer_")
      expect(MiqAlert).to receive(:evaluate_alerts).with(@ems_kub, "_hourly_timer_")
      MiqAlert.evaluate_hourly_timer
    end

    it "evaluates for vm" do
      vm_in_zone = FactoryBot.create(:vm_vmware, :ext_management_system => @ems)
      vm_in_other = FactoryBot.create(:vm_vmware, :ext_management_system => @ems_other)
      vm_no_ems = FactoryBot.create(:vm_vmware)
      @alert.update(:db => "Vm")
      @alert_prof.mode = vm_in_zone.class.base_model.name
      @alert_prof.assign_to_objects(vm_in_zone.id, "Vm")

      expect(MiqAlert).to receive(:evaluate_alerts).once.with(vm_in_zone, "_hourly_timer_")
      expect(MiqAlert).to receive(:evaluate_alerts).once.with(vm_no_ems, "_hourly_timer_")
      expect(MiqAlert).not_to receive(:evaluate_alerts).with(vm_in_other, "_hourly_timer_")
      MiqAlert.evaluate_hourly_timer
    end

    it "evaluates for storage" do
      storage_in_zone = FactoryBot.create(:storage_vmware, :ems_id => @ems.id)
      FactoryBot.create(:host, :ext_management_system => @ems, :storages => [storage_in_zone])

      storage_in_another = FactoryBot.create(:storage_vmware, :ems_id => @ems_other.id)
      FactoryBot.create(:host, :ext_management_system => @ems_other, :storages => [storage_in_another])

      storage_in_host_no_ems = FactoryBot.create(:storage_vmware)
      FactoryBot.create(:host, :storages => [storage_in_host_no_ems])

      storage_no_ems = FactoryBot.create(:storage_vmware)

      @alert.update(:db => "Storage")
      @alert_prof.mode = storage_in_zone.class.base_model.name
      @alert_prof.assign_to_objects(storage_in_zone.id, "Storage")

      expect(MiqAlert).to receive(:evaluate_alerts).once.with(storage_in_zone, "_hourly_timer_")
      expect(MiqAlert).to receive(:evaluate_alerts).once.with(storage_in_host_no_ems, "_hourly_timer_")
      expect(MiqAlert).to receive(:evaluate_alerts).once.with(storage_no_ems, "_hourly_timer_")
      expect(MiqAlert).not_to receive(:evaluate_alerts).with(storage_in_another, "_hourly_timer_")
      MiqAlert.evaluate_hourly_timer
    end

    it "evaluates for container entities" do
      [:container_node, :container_group, :container_replicator, :container].each do |entity|
        container_entity_in_zone = FactoryBot.create(entity, :ext_management_system => @ems_kub)
        @alert.update(:db => entity.to_s.camelize)
        @alert_prof.mode = container_entity_in_zone.class.base_model.name
        @alert_prof.assign_to_objects(container_entity_in_zone.id, entity.to_s.camelize)
        expect(MiqAlert).to receive(:evaluate_alerts).once.with(container_entity_in_zone, "_hourly_timer_")
        MiqAlert.evaluate_hourly_timer
      end
    end
  end

  describe 'Mangement Event' do
    before do
      @miq_server = EvmSpecHelper.local_miq_server
      @vm         = FactoryBot.create(:vm_vmware)
      @alert      = FactoryBot.create(
        :miq_alert_vm,
        :options            => {:notifications => {:automate => {:event_name => 'test_event_alert'}}},
        :expression         => {:eval_method => "nothing", :mode => "internal", :options => {}},
        :responds_to_events => "request_vm_poweroff"
      )
      @alert_prof = FactoryBot.create(:miq_alert_set_vm, :alerts => [@alert])
      @alert_prof.assign_to_objects(@vm)
    end

    it 'queues evaluation of alert' do
      expect(MiqQueue).to receive(:put_unless_exists).with(
        :class_name  => @alert.class.name,
        :instance_id => @alert.id,
        :method_name => "evaluate",
        :args        => [[@vm.class.name, @vm.id], {}],
        :zone        => MiqServer.my_zone
      )
      MiqAlert.evaluate_alerts(@vm, 'request_vm_poweroff')
    end

    it 'raises event to automate' do
      MiqAlert.evaluate_alerts(@vm, 'request_vm_poweroff')
      msg = MiqQueue.first
      expect(MiqQueue).to receive(:put).with(
        :class_name  => "MiqAeEvent",
        :method_name => "raise_evm_event",
        :args        => ['test_event_alert', [@vm.class.name, @vm.id], anything],
        :role        => 'automate',
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => MiqServer.my_zone
      )
      status, message, result = msg.deliver
      msg.delivered(status, message, result)
    end
  end

  describe '.validate_automate_expressions' do
    it 'Does not allow creation of dwh_generic miq_alerts with delay_next_evaluation > 0 ' do
      expect do
        FactoryBot.create(
          :miq_alert,
          :options    => {:notifications => {:delay_next_evaluation => 600, :evm_event => {}}},
          :expression => {:eval_method => "dwh_generic"}
        )
      end.to raise_error(
        ActiveRecord::RecordInvalid,
        'Validation failed: MiqAlert: Notifications Datawarehouse alerts must have a 0 notification frequency'
      )
    end
  end

  describe "#valid?" do
    it "doesn't query for an unchanged record" do
      alert = FactoryBot.create(:miq_alert)
      expect { alert.valid? }.not_to make_database_queries
    end
  end
end
