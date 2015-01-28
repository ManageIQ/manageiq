require "spec_helper"

module MiqAeServiceOrchestrationStackSpec
  describe MiqAeMethodService::MiqAeServiceOrchestrationStack do
    let(:stack)           { FactoryGirl.create(:orchestration_stack) }
    let(:service_stack)   { MiqAeMethodService::MiqAeServiceOrchestrationStack.find(stack.id) }
    let(:service)         { FactoryGirl.create(:service) }
    let(:service_service) { MiqAeMethodService::MiqAeServiceService.find(service.id) }

    context "#add_to_service" do
      it "adds a stack to service_resources of a valid service" do
        service_stack.add_to_service(service_service)
        service.service_resources[0].resource_id.should   == stack.id
        service.service_resources[0].resource_type.should == stack.class.name
      end

      it "raises an error when adding a stack to an invalid service" do
        expect { service_stack.add_to_service('wrong type') }.to raise_error
      end
    end
  end
end
