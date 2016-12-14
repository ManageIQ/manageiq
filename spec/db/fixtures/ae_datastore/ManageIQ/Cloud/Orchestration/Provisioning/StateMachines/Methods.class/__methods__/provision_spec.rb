require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Provisioning/' \
                        'StateMachines/Methods.class/__methods__/provision.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::Provision do
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }

  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task,
                       :destination => service_orchestration,
                       :miq_request => request)
  end

  let(:svc_model_service) do
    MiqAeMethodService::MiqAeServiceService.find(service_orchestration.id)
  end

  let(:svc_model_miq_request_task) do
    MiqAeMethodService::MiqAeServiceMiqRequestTask.find(miq_request_task.id)
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

  before(:each) do
    allow(svc_model_miq_request_task).to receive(:destination) { svc_model_service }
  end

  it "provisions a stack through the service" do
    expect(svc_model_service).to receive(:deploy_orchestration_stack)
    described_class.new(ae_service).main
  end

  it "catches the error at stack provisioning" do
    allow(svc_model_service).to receive(:deploy_orchestration_stack) { raise "test failure" }
    described_class.new(ae_service).main

    expect(ae_service.root['ae_result']).to eq("error")
    expect(ae_service.root['ae_reason']).to eq("test failure")
    expect(request.reload.message).to eq("test failure")
  end

  it "truncates the error message exceeding 255 character limits" do
    long_error = 't' * 300
    allow(svc_model_service).to receive(:deploy_orchestration_stack) { raise long_error }
    described_class.new(ae_service).main

    expect(ae_service.root['ae_result']).to eq("error")
    expect(ae_service.root['ae_reason']).to eq(long_error)
    expect(request.reload.message).to eq('t' * 252 + '...')
  end
end
