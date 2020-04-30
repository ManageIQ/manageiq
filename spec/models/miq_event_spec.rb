RSpec.describe MiqEvent do
  context "seeded" do
    context ".raise_evm_job_event" do
      it "vm" do
        obj = FactoryBot.create(:vm_redhat)
        expect(MiqEvent).to receive(:raise_evm_event) do |target, raw_event, _inputs|
          target == obj && raw_event == "vm_scan_complete"
        end
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end

      it "container_image" do
        obj = FactoryBot.create(:container_image)
        expect(MiqEvent).to receive(:raise_evm_event) do |target, raw_event, _inputs|
          target == obj && raw_event == "container_image_scan_complete"
        end
        MiqEvent.raise_evm_job_event(
          obj,
          {:type => "container_image_scan", :suffix => "complete"},
          :container_image => obj
        )
      end

      it "host" do
        obj = FactoryBot.create(:host_vmware)
        expect(MiqEvent).to receive(:raise_evm_event) do |target, raw_event, _inputs|
          target == obj && raw_event == "host_scan_complete"
        end
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end

      it "physical_server" do
        obj = FactoryBot.create(:physical_server)
        expect(MiqEvent).to receive(:raise_evm_event) do |target, raw_event, _inputs|
          target == obj && raw_event == "physical_server_shutdown"
        end
        MiqEvent.raise_evm_job_event(obj, {:type => "shutdown"}, {})
      end
    end

    it "will recognize known events" do
      FactoryBot.create(:miq_event_definition, :name => "host_connect")
      expect(MiqEvent.normalize_event("host_connect")).not_to eq("unknown")

      FactoryBot.create(:miq_event_definition, :name => "evm_server_start")
      expect(MiqEvent.normalize_event("evm_server_start")).not_to eq("unknown")
    end

    it "will mark unknown events" do
      expect(MiqEvent.normalize_event("xxx")).to eq("unknown")
      expect(MiqEvent.normalize_event("unknown")).to eq("unknown")
    end

    context ".event_name_for_target" do
      it "vm" do
        expect(MiqEvent.event_name_for_target(FactoryBot.build(:vm_redhat),   "perf_complete")).to eq("vm_perf_complete")
      end

      it "host" do
        expect(MiqEvent.event_name_for_target(FactoryBot.build(:host_redhat), "perf_complete")).to eq("host_perf_complete")
      end
    end

    context ".raise_evm_event" do
      before do
        @cluster    = FactoryBot.create(:ems_cluster)
        @miq_server = EvmSpecHelper.local_miq_server
        @zone       = @miq_server.zone
      end

      it "will raise an error for missing target" do
        expect { MiqEvent.raise_evm_event([:MiqServer, 30_000], "some_event") }
          .to raise_error(RuntimeError, /Unable to find object for target/)
      end

      it "will raise an error for nil target" do
        expect { MiqEvent.raise_evm_event(nil, "some_event") }
          .to raise_error(RuntimeError, /Unable to find object for target/)
      end

      it "will raise the event to automate given target directly" do
        event = 'evm_server_start'
        FactoryBot.create(:miq_event_definition, :name => event)
        expect(MiqAeEvent).to receive(:raise_evm_event)
        MiqEvent.raise_evm_event(@miq_server, event)
      end

      it "will raise the event to automate given target type and id" do
        event = 'evm_server_start'
        FactoryBot.create(:miq_event_definition, :name => event)
        expect(MiqAeEvent).to receive(:raise_evm_event)
        MiqEvent.raise_evm_event([:MiqServer, @miq_server.id], event)
      end

      it "will raise undefined event for classes that do not support policy" do
        service = FactoryBot.create(:service)
        expect(MiqAeEvent).to receive(:raise_evm_event)
        MiqEvent.raise_evm_event(service, "request_service_retire")
      end

      it "will not raise undefined event for classes that support policy" do
        expect(MiqAeEvent).not_to receive(:raise_evm_event)
        MiqEvent.raise_evm_event(@miq_server, "evm_server_start")
      end

      it "will create miq_event object with username" do
        user = FactoryBot.create(:user_with_group, :userid => "test")
        vm = FactoryBot.create(:vm_vmware)
        event = 'request_vm_start'
        FactoryBot.create(:miq_event_definition, :name => event)

        User.with_user(user) do
          event_obj = MiqEvent.raise_evm_event(vm, event)
          expect(event_obj.user_id).to eq(user.id)
          expect(event_obj.group_id).to eq(user.current_group.id)
          expect(event_obj.tenant_id).to eq(user.current_tenant.id)
        end
      end
    end

    context "#process_evm_event" do
      before do
        @cluster    = FactoryBot.create(:ems_cluster)
        @zone       = FactoryBot.create(:zone, :name => "test")
        @miq_server = FactoryBot.create(:miq_server, :zone => @zone)
      end

      it "will do policy, alerts, and children events for supported policy target" do
        event = 'vm_start'
        FactoryBot.create(:miq_event_definition, :name => event)
        FactoryBot.create(:miq_event, :event_type => event, :target => @cluster)
        inputs = {:type => @cluster.class.name, :triggering_type => event, :triggering_data => nil}
        expect(MiqPolicy).to receive(:enforce_policy).with(@cluster, event, inputs)
        expect(MiqAlert).to receive(:evaluate_alerts).with(@cluster, event, inputs)
        expect(MiqEvent).to receive(:raise_event_for_children).with(@cluster, event, inputs)

        results = MiqEvent.first.process_evm_event
        expect(results.keys).to match_array([:policy, :alert, :children_events])
      end

      it "will not raise to automate for supported policy target" do
        raw_event = "evm_server_start"
        FactoryBot.create(:miq_event_definition, :name => raw_event)
        FactoryBot.create(:miq_event, :event_type => raw_event, :target => @miq_server)

        expect(MiqAeEvent).to receive(:raise_evm_event).never
        MiqEvent.first.process_evm_event
      end

      it "will do nothing for unsupported policy target" do
        FactoryBot.create(:miq_event_definition, :name => "some_event")
        FactoryBot.create(:miq_event, :event_type => "some_event", :target => @zone)

        expect(MiqPolicy).to receive(:enforce_policy).never
        expect(MiqAlert).to receive(:evaluate_alerts).never
        expect(MiqEvent).to receive(:raise_event_for_children).never
        MiqEvent.first.process_evm_event
      end

      it "will do policy for provider events" do
        event = 'ems_auth_changed'
        ems = FactoryBot.create(:ext_management_system)
        FactoryBot.create(:miq_event_definition, :name => event)
        FactoryBot.create(:miq_event, :event_type => event, :target => ems)
        inputs = {:type => ems.class.name, :triggering_type => event, :triggering_data => nil}

        expect(MiqPolicy).to receive(:enforce_policy).with(ems, event, inputs)
        MiqEvent.first.process_evm_event
      end

      it "will pass EmsEvent to policy if set" do
        event = 'vm_clone_start'
        vm = FactoryBot.create(:vm_vmware)
        ems_event = FactoryBot.create(
          :ems_event,
          :event_type => "CloneVM_Task",
          :full_data  => { "info" => {"task" => "task-5324"}})
        FactoryBot.create(:miq_event_definition, :name => event)
        FactoryBot.create(
          :miq_event,
          :event_type => event,
          :target     => vm,
          :full_data  => {:source_event_id => ems_event.id})
        inputs = {
          :type            => vm.class.name,
          :source_event    => ems_event,
          :triggering_type => event,
          :triggering_data => {:source_event_id => ems_event.id}
        }

        expect(MiqPolicy).to receive(:enforce_policy).with(
          vm,
          event,
          inputs
        )
        MiqEvent.first.process_evm_event
      end
    end

    context ".raise_event_for_children" do
      it "uses base_model to build event name" do
        host = FactoryBot.create(:host_vmware_esx)
        vm = FactoryBot.create(:vm_vmware, :host => host)
        expect(MiqEvent).to receive(:raise_evm_event_queue) do |target, child_event, _inputs|
          target == vm && child_event == "assigned_company_tag_parent_host"
        end
        MiqEvent.raise_event_for_children(host, "assigned_company_tag")
      end
    end
  end
end
