require "spec_helper"

module MiqAeDiscoverySpec
  include MiqAeEngine
  describe "MiqAeDiscovery" do
    before(:each) do
      @vm     = FactoryGirl.create(:vm_vmware)
      @event  = FactoryGirl.create(:ems_event, :event_type => "CreateVM_Task_Complete",
                                  :source => "VC", :ems_id => 1, :vm_or_template_id => @vm.id)
      @domain = "SPEC_DOMAIN"
      # admin user is needed to process Events
      @admin = FactoryGirl.create(:user_with_group, :userid => "admin", :name => "Administrator")
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "discovery"), @domain)
    end

    it "properly processes MiqAeEvent.raise_ems_event" do
      ws = MiqAeEvent.raise_ems_event(@event)
      ws.should_not be_nil
    end

    context "automate deliver" do
      let(:workspace) { instance_double("MiqAeEngine::MiqAeWorkspace", :root => options) }
      let(:options) { {'test' => true} }

      it "check automate parameters" do
        attrs = {:event_id          => @event.id,
                 :event_type        => @event.event_type,
                 "VmOrTemplate::vm" => @vm.id,
                 :vm_id             => @vm.id}

        identifiers = {:user_id      => @admin.id,
                       :miq_group_id => @admin.current_group.id,
                       :tenant_id    => @admin.current_tenant.id}

        args = {:object_type      => "EmsEvent",
                :object_id        => @event.id,
                :attrs            => attrs,
                :instance_name    => "Event",
                :automate_message => nil,
                :state            => nil}.merge(identifiers)

        MiqAeEngine.should_receive(:deliver).with(args).and_return(workspace)
        ws = MiqAeEvent.raise_ems_event(@event)
        expect(ws.root['test']).to be_true
      end
    end

    it "properly processes Vm Scan Request" do
      ws = MiqAeEngine.instantiate("/EVM/VMSCAN/foo?target_vm_id=#{@vm.id}")
      ws.should_not be_nil
    end
  end
end
