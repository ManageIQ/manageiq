require "spec_helper"
require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/ConfigurationManagement/AnsibleTower/Service/Provisioning/StateMachines/Provision.class/__methods__/check_provisioned').to_s
require Rails.root.join('spec/support/miq_ae_mock_service').to_s

describe AnsibleTowerCheckProvisioned do
  let(:admin) { FactoryGirl.create(:user_admin) }
  let(:request) { FactoryGirl.create(:service_template_provision_request, :requester => admin) }
  let(:service_ansible_tower) { FactoryGirl.create(:service_ansible_tower) }
  let(:task) { FactoryGirl.create(:service_template_provision_task, :destination => service_ansible_tower, :miq_request => request) }
  let(:svc_task) { MiqAeMethodService::MiqAeServiceServiceTemplateProvisionTask.find(task.id) }
  let(:root_object) { MiqAeMockObject.new('service_template_provision_task' => svc_task) }
  let(:ae_service) { MiqAeMockService.new(root_object) }
  let(:job_class) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager_Job }
  let(:job) { FactoryGirl.create(:ansible_tower_job) }

  describe 'check provision status' do
    before { allow_any_instance_of(ServiceAnsibleTower).to receive(:job).and_return(job) }

    context 'ansible tower job completed' do
      before { allow_any_instance_of(job_class).to receive(:normalized_live_status).and_return(['create_complete', 'ok']) }
      it "refreshes the job status" do
        expect(job).to receive(:refresh_ems)
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('ok')
      end
    end

    context 'ansible tower job is running' do
      before { allow_any_instance_of(job_class).to receive(:normalized_live_status).and_return(['running', 'ok']) }
      it "retries the step" do
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('retry')
      end
    end

    context 'ansible tower job failed' do
      before { allow_any_instance_of(job_class).to receive(:normalized_live_status).and_return(['create_failed', 'bad']) }
      it "signals error" do
        expect(job).to receive(:refresh_ems)
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('error')
        expect(ae_service.root['ae_reason']).to eq('bad')
      end
    end
  end
end
