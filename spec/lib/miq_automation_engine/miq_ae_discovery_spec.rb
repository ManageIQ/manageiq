require "spec_helper"

module MiqAeDiscoverySpec
  include MiqAeEngine
  describe "MiqAeDiscovery" do
    before(:each) do
      @vm     = FactoryGirl.create(:vm_vmware)
      @event  = FactoryGirl.create(:ems_event, :event_type => "CreateVM_Task_Complete",
                                  :source => "VC", :ems_id => 1, :vm_or_template_id => @vm.id)
      @domain = "SPEC_DOMAIN"
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "discovery"), @domain)
    end

    it "properly processes MiqAeEvent.raise_ems_event" do
      ws = MiqAeEvent.raise_ems_event(@event)
      ws.should_not be_nil
    end

    it "properly processes Vm Scan Request" do
      ws = MiqAeEngine.instantiate("/EVM/VMSCAN/foo?target_vm_id=#{@vm.id}")
      ws.should_not be_nil
    end

  end
end
