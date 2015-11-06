require "spec_helper"

module MiqAeDiscoverySpec
  include MiqAeEngine
  describe "MiqAeDiscovery" do
    before(:each) do
      # admin user is needed to process Events
      @admin  = User.super_admin || FactoryGirl.create(:user_with_group, :userid => "admin")
      @tenant = Tenant.root_tenant
      @group  = FactoryGirl.create(:miq_group, :tenant => @tenant)
      @ems    = FactoryGirl.create(:ext_management_system, :tenant => @tenant)
      @vm     = FactoryGirl.create(:vm_vmware, :miq_group => @group)
      @event  = FactoryGirl.create(:ems_event, :event_type => "CreateVM_Task_Complete",
                                  :source => "VC", :ems_id => @ems.id, :vm_or_template_id => @vm.id)
      @domain = "SPEC_DOMAIN"
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "discovery"), @domain)
    end

    it "properly processes MiqAeEvent.raise_ems_event" do
      MiqAeEngine.should_receive(:deliver_queue)
      MiqAeEvent.raise_ems_event(@event)
    end

    context "automate deliver" do
      it "check automate parameters" do
        attrs = {:event_id                  => @event.id,
                 :event_type                => @event.event_type,
                 :event_stream_id           => @event.id,
                 "ExtManagementSystem::ems" => @ems.id,
                 :ems_id                    => @ems.id,
                 "VmOrTemplate::vm"         => @vm.id,
                 :vm_id                     => @vm.id,
        }

        args = {:object_type      => "EmsEvent",
                :object_id        => @event.id,
                :attrs            => attrs,
                :instance_name    => "Event",
                :user_id          => @admin.id,
                :miq_group_id     => @group.id,
                :tenant_id        => @tenant.id,
                :automate_message => nil}

        MiqAeEngine.should_receive(:deliver_queue).with(args, anything)
         MiqAeEvent.raise_ems_event(@event)
      end
    end

    it "properly processes Vm Scan Request" do
      ws = MiqAeEngine.instantiate("/EVM/VMSCAN/foo?target_vm_id=#{@vm.id}", @admin)
      ws.should_not be_nil
    end
  end
end
