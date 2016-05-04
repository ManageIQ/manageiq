require "spec_helper"
require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/ConfigurationManagement/AnsibleTower/Operations/StateMachines/Job.class/__methods__/wait_for_completion').to_s
require Rails.root.join('spec/support/miq_ae_mock_service').to_s

describe WaitForCompletion do
  let(:job_class) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager_Job }
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:svc_vm) { MiqAeMethodService::MiqAeServiceVm.find(vm.id) }
  let(:job_template) { FactoryGirl.create(:configuration_script) }
  let(:svc_job_template) { MiqAeMethodService::MiqAeServiceConfigurationScript.find(job_template.id) }
  let(:ip_addr) { '1.1.1.1' }
  let(:job) { FactoryGirl.create(:ansible_tower_job) }
  let(:svc_job) { job_class.find(job.id) }
  let(:persist_state_hash) { {:ansible_job_id => svc_job.id} }
  let(:service) { MiqAeMockService.new(MiqAeMockObject.new({}), persist_state_hash) }

  it "job status successful" do
    expect_any_instance_of(job_class).to receive(:normalized_live_status).with(no_args).and_return(%w(create_complete ok))
    expect_any_instance_of(job_class).to receive(:refresh_ems).with(no_args).and_return(nil)
    described_class.new(service).main
    expect(service.root['ae_result']).to eq('ok')
  end

  it "job status running" do
    expect_any_instance_of(job_class).to receive(:normalized_live_status).with(no_args).and_return(%w(transient ok))
    described_class.new(service).main
    expect(service.root['ae_result']).to eq('retry')
  end

  it "job status failed" do
    expect_any_instance_of(job_class).to receive(:normalized_live_status).with(no_args).and_return(%w(failed ok))
    expect_any_instance_of(job_class).to receive(:refresh_ems).with(no_args).and_return(nil)
    described_class.new(service).main
    expect(service.root['ae_result']).to eq('error')
  end

  it "job status canceled" do
    expect_any_instance_of(job_class).to receive(:normalized_live_status).with(no_args).and_return(%w(create_canceled ok))
    expect_any_instance_of(job_class).to receive(:refresh_ems).with(no_args).and_return(nil)
    described_class.new(service).main
    expect(service.root['ae_result']).to eq('error')
  end
end
