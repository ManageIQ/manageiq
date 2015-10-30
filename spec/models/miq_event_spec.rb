require "spec_helper"

describe MiqEvent do
  context "seeded" do
    context ".raise_evm_job_event" do
      it "vm" do
        obj = FactoryGirl.create(:vm_redhat)
        MiqEvent.should_receive(:raise_evm_event).with { |target, raw_event, _inputs| target == obj && raw_event == "vm_scan_complete" }
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end

      it "host" do
        obj = FactoryGirl.create(:host_vmware)
        MiqEvent.should_receive(:raise_evm_event).with { |target, raw_event, _inputs| target == obj && raw_event == "host_scan_complete" }
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end
    end

    it "will recognize known events" do
      FactoryGirl.create(:miq_event_definition, :name => "host_connect")
      MiqEvent.normalize_event("host_connect").should_not == "unknown"

      FactoryGirl.create(:miq_event_definition, :name => "evm_server_start")
      MiqEvent.normalize_event("evm_server_start").should_not == "unknown"
    end

    it "will mark unknown events" do
      MiqEvent.normalize_event("xxx").should == "unknown"
      MiqEvent.normalize_event("unknown").should == "unknown"
    end

    context ".event_name_for_target" do
      it "vm" do
        MiqEvent.event_name_for_target(FactoryGirl.build(:vm_redhat),   "perf_complete").should == "vm_perf_complete"
      end

      it "host" do
        MiqEvent.event_name_for_target(FactoryGirl.build(:host_redhat), "perf_complete").should == "host_perf_complete"
      end
    end

    context ".raise_evm_event" do
      before(:each) do
        @cluster    = FactoryGirl.create(:ems_cluster)
        @miq_server = EvmSpecHelper.local_miq_server
        @zone       = @miq_server.zone
      end

      it "will raise an error for missing target" do
        -> { MiqEvent.raise_evm_event([:MiqServer, 30000], "some_event") }.should raise_error
      end

      it "will raise an error for nil target" do
        expect { MiqEvent.raise_evm_event(nil, "some_event") }.to raise_error
      end

      it "will raise the event to automate given target directly" do
        event = 'evm_server_start'
        FactoryGirl.create(:miq_event_definition, :name => event)
        MiqAeEvent.should_receive(:raise_evm_event)
        MiqEvent.raise_evm_event(@miq_server, event)
      end

      it "will raise the event to automate given target type and id" do
        event = 'evm_server_start'
        FactoryGirl.create(:miq_event_definition, :name => event)
        MiqAeEvent.should_receive(:raise_evm_event)
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

        MiqPolicy.should_receive(:enforce_policy).with(@cluster, event, :type => target_class)
        MiqAlert.should_receive(:evaluate_alerts).with(@cluster, event, :type => target_class)
        MiqEvent.should_receive(:raise_event_for_children).with(@cluster, event, :type => target_class)

        results = MiqEvent.first.process_evm_event
        results.keys.should match_array([:policy, :alert, :children_events])
      end

      it "will not raise to automate for supported policy target" do
        raw_event = "evm_server_start"
        FactoryGirl.create(:miq_event_definition, :name => raw_event)
        FactoryGirl.create(:miq_event, :event_type => raw_event, :target => @miq_server)

        MiqAeEvent.should_receive(:raise_evm_event).never
        MiqEvent.first.process_evm_event
      end

      it "will do nothing for unsupported policy target" do
        FactoryGirl.create(:miq_event_definition, :name => "some_event")
        FactoryGirl.create(:miq_event, :event_type => "some_event", :target => @zone)

        MiqPolicy.should_receive(:enforce_policy).never
        MiqAlert.should_receive(:evaluate_alerts).never
        MiqEvent.should_receive(:raise_event_for_children).never
        MiqEvent.first.process_evm_event
      end
    end

    context ".raise_event_for_children" do
      it "uses base_model to build event name" do
        host = FactoryGirl.create(:host_vmware_esx)
        vm = FactoryGirl.create(:vm_vmware, :host => host)
        MiqEvent.should_receive(:raise_evm_event_queue).with { |target, child_event, _inputs| target == vm && child_event == "assigned_company_tag_parent_host" }
        MiqEvent.raise_event_for_children(host, "assigned_company_tag")
      end
    end
  end
end
