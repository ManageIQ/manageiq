require "spec_helper"

module MiqAeServiceServiceOrchestrationSpec
  describe MiqAeMethodService::MiqAeServiceServiceOrchestration do
    let(:orch_template)    { FactoryGirl.create(:orchestration_template) }
    let(:orch_manager)     { FactoryGirl.create(:ems_amazon) }
    let(:stack_opts)       { {'any_key' => 'any_value'} }
    let(:ae_orch_template) { MiqAeMethodService::MiqAeServiceOrchestrationTemplate.find(orch_template.id) }
    let(:ae_orch_manager)  { MiqAeMethodService::MiqAeServiceExtManagementSystem.find(orch_manager.id) }
    let(:service)          { FactoryGirl.create(:service_orchestration) }
    let(:service_service)  { MiqAeMethodService::MiqAeServiceService.find(service.id) }

    it "sets and gets orchestration_template" do
      service_service.orchestration_template = ae_orch_template
      service.orchestration_template.should == orch_template
      service_service.orchestration_template.object_class.name.should == 'OrchestrationTemplate'
    end

    it "sets and gets orchestration_manager" do
      service_service.orchestration_manager = ae_orch_manager
      service.orchestration_manager.should == orch_manager
      service_service.orchestration_manager.object_class.name.should == 'EmsAmazon'
    end

    it "sets and gets stack_name" do
      service_service.stack_name = 'stack_name'
      service_service.stack_name.should == 'stack_name'
    end

    it "sets and gets stack_options" do
      service_service.stack_options = stack_opts
      service_service.stack_options.should == stack_opts
    end
  end
end
