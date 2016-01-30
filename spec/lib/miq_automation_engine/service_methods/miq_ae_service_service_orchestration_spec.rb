module MiqAeServiceServiceOrchestrationSpec
  describe MiqAeMethodService::MiqAeServiceServiceOrchestration do
    let(:orch_template)    { FactoryGirl.create(:orchestration_template) }
    let(:orch_manager)     { FactoryGirl.create(:ems_amazon) }
    let(:stack_opts)       { {'any_key' => 'any_value'} }
    let(:ae_orch_template) { MiqAeMethodService::MiqAeServiceOrchestrationTemplate.find(orch_template.id) }
    let(:ae_orch_manager)  { MiqAeMethodService::MiqAeServiceExtManagementSystem.find(orch_manager.id) }
    let(:service_template) { FactoryGirl.create(:service_template_orchestration) }
    let(:ss_template)      { MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
    let(:service)          { FactoryGirl.create(:service_orchestration, :service_template => service_template) }
    let(:service_service)  { MiqAeMethodService::MiqAeServiceService.find(service.id) }

    it "sets and gets orchestration_template" do
      service_service.orchestration_template = ae_orch_template
      expect(service.orchestration_template).to eq(orch_template)
      expect(service_service.orchestration_template.object_class.name).to eq('OrchestrationTemplate')
    end

    it "sets and gets orchestration_manager" do
      service_service.orchestration_manager = ae_orch_manager
      expect(service.orchestration_manager).to eq(orch_manager)
      expect(service_service.orchestration_manager.object_class.name).to eq('ManageIQ::Providers::Amazon::CloudManager')
    end

    it "sets and gets stack_name" do
      service_service.stack_name = 'stack_name'
      expect(service_service.stack_name).to eq('stack_name')
    end

    it "sets and gets stack_options" do
      service_service.stack_options = stack_opts
      expect(service_service.stack_options).to eq(stack_opts)
    end

    it "sets and gets update_options" do
      service_service.update_options = stack_opts
      expect(service_service.update_options).to eq(stack_opts)
    end

    it "allows to assign orchestration_template from service_template" do
      service_template.orchestration_template = orch_template

      service_service.orchestration_template = service_service.service_template.orchestration_template

      expect(service.orchestration_template).to eq(orch_template)
    end
  end
end
