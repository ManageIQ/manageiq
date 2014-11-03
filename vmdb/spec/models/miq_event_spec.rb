require "spec_helper"

describe MiqEvent do
  context "seeded" do
    before(:each) do
      MiqRegion.seed
    end

    context ".raise_evm_job_event" do
      it "vm" do
        obj = FactoryGirl.create(:vm_redhat)
        MiqEvent.should_receive(:raise_evm_event).with { |target, raw_event, inputs| target == obj && raw_event == "vm_scan_complete" }
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end

      it "host" do
        obj = FactoryGirl.create(:host_vmware)
        MiqEvent.should_receive(:raise_evm_event).with { |target, raw_event, inputs| target == obj && raw_event == "host_scan_complete" }
        MiqEvent.raise_evm_job_event(obj, {:type => "scan", :suffix => "complete"}, {})
      end
    end

    it "will recognize known events" do
      FactoryGirl.create(:miq_event, :name => "host_connect")
      MiqEvent.normalize_event("host_connect").should_not == "unknown"

      FactoryGirl.create(:miq_event, :name => "evm_server_start")
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
        @guid       = MiqUUID.new_guid
        @zone       = FactoryGirl.create(:zone, :name => "test")
        @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
        MiqServer.stub(:my_guid).and_return(@guid)
        MiqServer.stub(:my_server).and_return(@miq_server)
      end

      it "will raise an error for missing target" do
        lambda { MiqEvent.raise_evm_event([:MiqServer, 30000], "some_event")}.should raise_error
      end

      it "will raise an error for nil target" do
        expect { MiqEvent.raise_evm_event(nil, "some_event") }.to raise_error
      end

      it "will do policy, alerts, and children events for known event on supported policy target" do
        MiqAeEvent.should_receive(:raise_evm_event).never
        raw_event = 'vm_start'
        FactoryGirl.create(:miq_event, :name => raw_event)
        event = MiqEvent.normalize_event(raw_event)
        MiqPolicy.should_receive(:enforce_policy).with(@cluster, event, {:type => @cluster.class.name } )
        MiqAlert.should_receive(:evaluate_alerts).with(@cluster, event, {:type => @cluster.class.name } )
        MiqEvent.should_receive(:raise_event_for_children).with(@cluster, raw_event, {:type => @cluster.class.name } )
        results = MiqEvent.raise_evm_event(@cluster, event)

        results.keys.should match_array([:policy, :alert, :children_events])
        results.should_not have_key(:automate)
      end

      it "will do alerts and children events for unknown but alertable event on supported policy target" do
        MiqAeEvent.should_receive(:raise_evm_event).never
        MiqAlert.stub(:event_alertable?).and_return true
        MiqPolicy.should_receive(:enforce_policy).never
        MiqAlert.should_receive(:evaluate_alerts).with(@cluster, "unknown", {:type => @cluster.class.name} )
        MiqEvent.should_receive(:raise_event_for_children).with(@cluster, "unknown", {:type => @cluster.class.name} )
        MiqEvent.raise_evm_event(@cluster, "unknown")
      end

      it "will do children events for unknown and not alertable event on supported policy target" do
        MiqAeEvent.should_receive(:raise_evm_event).never
        MiqAlert.stub(:event_alertable?).and_return false
        MiqPolicy.should_receive(:enforce_policy).never
        MiqAlert.should_receive(:evaluate_alerts).never
        MiqEvent.should_receive(:raise_event_for_children).with(@cluster, "unknown", {:type => @cluster.class.name} )
        MiqEvent.raise_evm_event(@cluster, "unknown")
      end

      it "will alert, enforce policy and not raise to automate for known alertable event on supported policy target" do
        raw_event = "evm_server_start"
        FactoryGirl.create(:miq_event, :name => raw_event)
        event = MiqEvent.normalize_event(raw_event)
        MiqAlert.stub(:event_alertable?).with(raw_event).and_return true
        MiqAeEvent.should_receive(:raise_evm_event).never
        MiqPolicy.should_receive(:enforce_policy).once
        MiqAlert.should_receive(:evaluate_alerts).with(@miq_server, event, {:type => @miq_server.class.name })
        MiqEvent.should_receive(:raise_event_for_children).once
        MiqEvent.raise_evm_event(@miq_server, raw_event)
      end

      it "will not raise to automate for known non-alertable event on supported policy target" do
        raw_event = "evm_server_start"
        FactoryGirl.create(:miq_event, :name => raw_event)
        event = MiqEvent.normalize_event(raw_event)
        MiqAlert.stub(:event_alertable?).with(raw_event).and_return false
        MiqAeEvent.should_receive(:raise_evm_event).never
        MiqPolicy.should_receive(:enforce_policy).once
        MiqAlert.should_receive(:evaluate_alerts).once
        MiqEvent.should_receive(:raise_event_for_children).once
        MiqEvent.raise_evm_event(@miq_server, raw_event)
      end

      it "will not raise to automate for known non-alertable event on supported policy target without raising any errors" do
        raw_event = "evm_worker_start"
        FactoryGirl.create(:miq_event, :name => raw_event)
        MiqAlert.stub(:event_alertable?).with(raw_event).and_return false
        MiqPolicy.should_receive(:enforce_policy).once
        MiqAlert.should_receive(:evaluate_alerts).once
        MiqEvent.should_receive(:raise_event_for_children).once

        msg = "Worker started: ID [1], PID [123], GUID [c67bd040-3500-11df-81df-000c295b1696]"
        lambda {
          MiqEvent.raise_evm_event(@miq_server, raw_event, :event_details => msg, :type => "MiqGenericWorker")
        }.should_not raise_error
      end

      it "will alert and raise to automate for unknown but alertable event on unsupported policy target" do
        MiqAlert.stub(:event_alertable?).and_return true
        MiqAeEvent.should_receive(:raise_evm_event).with("unknown", @zone, :type => 'Zone')
        MiqPolicy.should_receive(:enforce_policy).never
        MiqAlert.should_receive(:evaluate_alerts).with(@zone, "unknown", :type => 'Zone')
        MiqEvent.should_receive(:raise_event_for_children).never
        MiqEvent.raise_evm_event(@zone, "unknown")
      end

      it "will raise to automate for unknown event on unsupported policy target" do
        MiqAeEvent.should_receive(:raise_evm_event).with("unknown", @zone, :type => 'Zone')
        MiqPolicy.should_receive(:enforce_policy).never
        MiqAlert.should_receive(:evaluate_alerts).never
        MiqEvent.should_receive(:raise_event_for_children).never
        MiqEvent.raise_evm_event(@zone, "unknown")
      end
    end
    
    context ".raise_event_for_children" do
      it "uses base_model to build event name" do
        host = FactoryGirl.create(:host_vmware_esx)
        vm = FactoryGirl.create(:vm_vmware, :host => host)
        MiqEvent.should_receive(:raise_evm_event_queue).with { |target, child_event, inputs| target == vm && child_event == "assigned_company_tag_parent_host" }
        MiqEvent.raise_event_for_children(host, "assigned_company_tag")
      end
    end
  end
end
