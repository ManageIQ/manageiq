require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration' \
                        '/Provisioning/StateMachines/Methods.class/' \
                        '__methods__/preprovision.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::PreProvision do
  let(:request)                 { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:user)                    { FactoryGirl.create(:user_with_group) }
  let(:ems_amazon)              { FactoryGirl.create(:ems_amazon) }
  let(:orchestration_template)  { FactoryGirl.create(:orchestration_template) }

  let(:service_orchestration) do
    FactoryGirl.create(:service_orchestration,
                       :orchestration_manager  => ems_amazon,
                       :orchestration_template => orchestration_template,
                       :stack_name             => 'stack_name')
  end

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

  let(:svc_model_miq_request_task) do
    MiqAeMethodService::MiqAeServiceMiqRequestTask.find(miq_request_task.id)
  end

  let(:svc_model_orchestration_manager) do
    MiqAeMethodService::MiqAeServiceExtManagementSystem.find(ems_amazon.id)
  end

  let(:svc_model_orchestration_template) do
    MiqAeMethodService::MiqAeServiceOrchestrationTemplate.find(orchestration_template.id)
  end

  before do
    allow(svc_model_miq_request_task).to receive(:orchestration_manager)
      .and_return(svc_model_orchestration_manager)
    allow(svc_model_miq_request_task).to receive(:orchestration_template)
      .and_return(svc_model_orchestration_template)
  end

  it "method logs exactly 4 times" do
    expect(ae_service).to receive(:log).exactly(4).times
    described_class.new(ae_service).main
  end

  context "service is nil" do
    let(:root_hash) { {} }
    let(:root_object) { {} }

    it "raises Service is nil exception" do
      expect { described_class.new(ae_service).main }.to raise_error("Service is nil")
    end
  end
end
