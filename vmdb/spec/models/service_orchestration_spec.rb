require "spec_helper"

describe ServiceTemplate do
  let(:orch_manager) { FactoryGirl.create(:ems_amazon) }
  let(:orch_template) { FactoryGirl.create(:orchestration_template) }
  let(:service) { FactoryGirl.create(:service_orchestration) }

  let(:dialog_options) do
    {
      'dialog_stack_template'                 => '1',
      'dialog_stack_manager'                  => '1',
      'dialog_stack_name'                     => 'test123',
      'dialog_stack_onfailure'                => 'ROLLBACK',
      'dialog_stack_timeout'                  => '30',
      'dialog_param_InstanceType'             => 'cg1.4xlarge',
      'password::dialog_param_DBRootPassword' => 'v2:{c2XR8/Yl1CS0phoOVMNU9w==}'
    }
  end

  let(:service_with_dialog_options) do
    service.options = {:dialog => dialog_options}
    service
  end

  let(:service_fully_loaded) do
    service.orchestration_template = orch_template
    service.orchestration_manager = orch_manager
    service.options = {:dialog => dialog_options}
    service
  end

  context "#stack_name" do
    it "gets stack name from dialog options" do
      name = service_with_dialog_options.stack_name
      name.should == 'test123'
    end

    it "gets stack name from overridden value" do
      service_orch = service_with_dialog_options
      service_orch.stack_name = "new_name"
      service_orch.stack_name.should == "new_name"
    end
  end

  context "#stack_options" do
    before do
      allow_any_instance_of(ServiceOrchestration::OptionConverterAmazon).to(
        receive(:stack_create_options).and_return(dialog_options))
      allow(OrchestrationTemplate).to receive(:find).and_return(FactoryGirl.create(:orchestration_template))
      allow(ExtManagementSystem).to receive(:find).and_return(FactoryGirl.create(:ems_amazon))
    end

    it "gets stack options set by dialog" do
      service_with_dialog_options.stack_options.should == dialog_options
    end

    it "gets stack options from overridden values" do
      new_options = { "any_key" => "any_value" }
      service_with_dialog_options.stack_options = new_options
      service_with_dialog_options.stack_options.should == new_options
    end

    it "prefers the orchestration template set by dialog" do
      service_fully_loaded.orchestration_template.should == orch_template
      service_fully_loaded.stack_options
      service_fully_loaded.orchestration_template.should_not == orch_template
      service_fully_loaded.orchestration_template.should be_kind_of OrchestrationTemplate
    end

    it "prefers the orchestration manager set by dialog" do
      service_fully_loaded.orchestration_manager.should == orch_manager
      service_fully_loaded.stack_options
      service_fully_loaded.orchestration_manager.should_not == orch_manager
      service_fully_loaded.orchestration_manager.should be_kind_of ExtManagementSystem
    end
  end

end
