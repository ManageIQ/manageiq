
require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration' \
  '/Provisioning/StateMachines/Methods.class/__methods__/postprovision.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::PostProvision do
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }
  let(:output)                { FactoryGirl.create(:orchestration_stack_output, :key => 'key', :value => 'value') }
  let(:orchestration_stack)   { FactoryGirl.create(:orchestration_stack_amazon, :name => "name", :outputs => [output]) }

  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task,
                       :destination => service_orchestration,
                       :miq_request => request)
  end

  let(:root_hash) do
    { 'service_template' => MiqAeMethodService::MiqAeServiceService.find(service_orchestration.id) }
  end

  let(:root_object) do
    obj = Spec::Support::MiqAeMockObject.new(root_hash)
    obj["service_template_provision_task"] = svc_model_miq_request_task
    obj
  end

  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
    end
  end

  let(:svc_model_service)      { MiqAeMethodService::MiqAeServiceService.find(service_orchestration.id) }
  let(:svc_model_amazon_stack) { MiqAeMethodService::MiqAeServiceOrchestrationStack.find(orchestration_stack.id) }
  let(:svc_model_output)       { MiqAeMethodService::MiqAeServiceOrchestrationStackOutput.find(output.id) }

  let(:svc_model_miq_request_task) do
    MiqAeMethodService::MiqAeServiceMiqRequestTask.find(miq_request_task.id)
  end

  before do
    allow(svc_model_miq_request_task).to receive(:destination)
      .and_return(svc_model_service)
  end

  it "updates the owners of the resulting vm" do
    allow(ae_service).to receive(:inputs) { {} }
    expect(svc_model_service).to receive(:post_provision_configure)
    described_class.new(ae_service).main
  end

  it "calling the dump_stack_outputs method" do
    allow(ae_service).to receive(:inputs) { {'debug' => true} }
    allow(svc_model_service).to receive(:orchestration_stack) { svc_model_amazon_stack }
    allow(svc_model_amazon_stack).to receive(:outputs) { [svc_model_output] }
    instance = described_class.new(ae_service)
    expect(instance).to receive(:dump_stack_outputs).with(svc_model_amazon_stack)
    instance.main
  end
end
