require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration' \
                        '/Provisioning/StateMachines/Methods.class/' \
                        '__methods__/check_provisioned.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::CheckProvisioned do
  let(:deploy_result)           { "deploy result" }
  let(:deploy_reason)           { "deploy reason" }
  let(:ems_amazon)              { FactoryGirl.create(:ems_amazon, :last_refresh_date => Time.now.getlocal - 100) }
  let(:failure_msg)             { "failure message" }
  let(:long_failure_msg)        { "t" * 300 }
  let(:request)                 { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration)   { FactoryGirl.create(:service_orchestration, :orchestration_manager => ems_amazon) }
  let(:user)                    { FactoryGirl.create(:user_with_group) }

  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task,
                       :destination => service_orchestration,
                       :miq_request => request)
  end

  let(:amazon_stack) do
    FactoryGirl.create(:orchestration_stack_amazon)
  end

  let(:svc_model_orchestration_manager) do
    MiqAeMethodService::MiqAeServiceExtManagementSystem.find(ems_amazon.id)
  end

  let(:svc_model_amazon_stack) do
    MiqAeMethodService::MiqAeServiceOrchestrationStack.find(amazon_stack.id)
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

  before do
    allow(svc_model_miq_request_task).to receive(:destination).and_return(svc_model_service)
  end

  it "waits for the deployment to complete" do
    allow(svc_model_service).to receive(:orchestration_stack_status) { ['CREATING', nil] }
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('retry')
  end

  it "catches the error during stack deployment" do
    allow(svc_model_service).to receive(:orchestration_stack_status).and_return(['CREATE_FAILED', failure_msg])
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('error')
    expect(ae_service.root['ae_reason']).to eq(failure_msg)
    expect(request.reload.message).to eq(failure_msg)
  end

  it "truncates the error message that exceeds 255 characters" do
    allow(svc_model_service).to receive(:orchestration_stack_status).and_return(['CREATE_FAILED', long_failure_msg])
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('error')
    expect(ae_service.root['ae_reason']).to eq(long_failure_msg)
    expect(request.reload.message).to eq('t' * 252 + '...')
  end

  it "considers rollback as provision error" do
    allow(svc_model_service)
      .to receive(:orchestration_stack_status) { ['ROLLBACK_COMPLETE', 'Stack was rolled back'] }
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('error')
    expect(ae_service.root['ae_reason']).to eq('Stack was rolled back')
  end

  context "refresh" do
    before do
      allow(svc_model_service).to receive(:orchestration_stack).and_return(svc_model_amazon_stack)
    end

    it "refreshes the provider and waits for it to complete" do
      allow(svc_model_service).to receive(:orchestration_manager).and_return(svc_model_orchestration_manager)
      allow(svc_model_service)
        .to receive(:orchestration_stack_status) { ['CREATE_COMPLETE', nil] }
      expect(svc_model_orchestration_manager).to receive(:refresh)
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq('retry')
    end

    it "waits the refresh to complete" do
      ae_service.set_state_var('provider_last_refresh', true)
      amazon_stack.status = "CREATE_IN_PROGRESS"
      amazon_stack.save
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq("retry")
    end

    it "completes check_provisioned step when refresh is done" do
      ae_service.set_state_var('provider_last_refresh', true)
      ae_service.set_state_var('deploy_result', deploy_result)
      ae_service.set_state_var('deploy_reason', deploy_reason)
      amazon_stack.status = "success"
      amazon_stack.save
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq(deploy_result)
    end
  end

  context "exceptions" do
    context "with nil service" do
      let(:root_hash) { {} }
      let(:svc_model_service) { nil }

      it "raises the service is nil exception" do
        expect { described_class.new(ae_service).main }.to raise_error('Service is nil')
      end
    end

    context 'with other than orchestration service' do
      let(:service_orchestration) { FactoryGirl.create(:service_ansible_tower) }

      it "raises the service has a different type exception" do
        expect { described_class.new(ae_service).main }.to raise_error(
          'Service has a different type from MiqAeServiceServiceOrchestration')
      end
    end
  end
end
