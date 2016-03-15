describe MiqEvent do
  context "seeded" do
    context ".raise_evm_job_event" do
      it "vm" do
        obj = FactoryGirl.create(:vm_redhat)
        expect(MiqEvent).to receive(:raise_evm_event) do |target, raw_event, _inputs|
          target == obj && raw_event == "vm_scan_complete"
        end
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end

      it "container_image" do
        obj = FactoryGirl.create(:container_image)
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
        obj = FactoryGirl.create(:host_vmware)
        expect(MiqEvent).to receive(:raise_evm_event) do |target, raw_event, _inputs|
          target == obj && raw_event == "host_scan_complete"
        end
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end
    end

    it "will recognize known events" do
      FactoryGirl.create(:miq_event_definition, :name => "host_connect")
      expect(MiqEvent.normalize_event("host_connect")).not_to eq("unknown")

      FactoryGirl.create(:miq_event_definition, :name => "evm_server_start")
      expect(MiqEvent.normalize_event("evm_server_start")).not_to eq("unknown")
    end

    it "will mark unknown events" do
      expect(MiqEvent.normalize_event("xxx")).to eq("unknown")
      expect(MiqEvent.normalize_event("unknown")).to eq("unknown")
    end

    context ".event_name_for_target" do
      it "vm" do
        expect(MiqEvent.event_name_for_target(FactoryGirl.build(:vm_redhat),   "perf_complete")).to eq("vm_perf_complete")
      end

      it "host" do
        expect(MiqEvent.event_name_for_target(FactoryGirl.build(:host_redhat), "perf_complete")).to eq("host_perf_complete")
      end
    end

    context ".raise_evm_event" do
      before(:each) do
        @cluster    = FactoryGirl.create(:ems_cluster)
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
        FactoryGirl.create(:miq_event_definition, :name => event)
        expect(MiqAeEvent).to receive(:raise_evm_event)
        MiqEvent.raise_evm_event(@miq_server, event)
      end

      it "will raise the event to automate given target type and id" do
        event = 'evm_server_start'
        FactoryGirl.create(:miq_event_definition, :name => event)
        expect(MiqAeEvent).to receive(:raise_evm_event)
        MiqEvent.raise_evm_event([:MiqServer, @miq_server.id], event)
      end

      it "will raise undefined event for classes that do not support policy" do
        service = FactoryGirl.create(:service)
        expect(MiqAeEvent).to receive(:raise_evm_event)
        MiqEvent.raise_evm_event(service, "request_service_retire")
      end

      it "will not raise undefined event for classes that support policy" do
        expect(MiqAeEvent).not_to receive(:raise_evm_event)
        MiqEvent.raise_evm_event(@miq_server, "evm_server_start")
      end
    end

    context "#process_evm_event" do
      before do
        @cluster    = FactoryGirl.create(:ems_cluster)
        @zone       = FactoryGirl.create(:zone, :name => "test")
        @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
      end

      it "will do policy, alerts, and children events for supported policy target" do
        event = 'vm_start'
        FactoryGirl.create(:miq_event_definition, :name => event)
        FactoryGirl.create(:miq_event, :event_type => event, :target => @cluster)
        target_class = @cluster.class.name

        expect(MiqPolicy).to receive(:enforce_policy).with(@cluster, event, :type => target_class)
        expect(MiqAlert).to receive(:evaluate_alerts).with(@cluster, event, :type => target_class)
        expect(MiqEvent).to receive(:raise_event_for_children).with(@cluster, event, :type => target_class)

        results = MiqEvent.first.process_evm_event
        expect(results.keys).to match_array([:policy, :alert, :children_events])
      end

      it "will not raise to automate for supported policy target" do
        raw_event = "evm_server_start"
        FactoryGirl.create(:miq_event_definition, :name => raw_event)
        FactoryGirl.create(:miq_event, :event_type => raw_event, :target => @miq_server)

        expect(MiqAeEvent).to receive(:raise_evm_event).never
        MiqEvent.first.process_evm_event
      end

      it "will do nothing for unsupported policy target" do
        FactoryGirl.create(:miq_event_definition, :name => "some_event")
        FactoryGirl.create(:miq_event, :event_type => "some_event", :target => @zone)

        expect(MiqPolicy).to receive(:enforce_policy).never
        expect(MiqAlert).to receive(:evaluate_alerts).never
        expect(MiqEvent).to receive(:raise_event_for_children).never
        MiqEvent.first.process_evm_event
      end

      it "will do policy for provider events" do
        event = 'ems_auth_changed'
        ems = FactoryGirl.create(:ext_management_system)
        FactoryGirl.create(:miq_event_definition, :name => event)
        FactoryGirl.create(:miq_event, :event_type => event, :target => ems)

        expect(MiqPolicy).to receive(:enforce_policy).with(ems, event, :type => ems.class.name)
        MiqEvent.first.process_evm_event
      end
    end

    context ".raise_event_for_children" do
      it "uses base_model to build event name" do
        host = FactoryGirl.create(:host_vmware_esx)
        vm = FactoryGirl.create(:vm_vmware, :host => host)
        expect(MiqEvent).to receive(:raise_evm_event_queue) do |target, child_event, _inputs|
          target == vm && child_event == "assigned_company_tag_parent_host"
        end
        MiqEvent.raise_event_for_children(host, "assigned_company_tag")
      end
    end
  end
end
