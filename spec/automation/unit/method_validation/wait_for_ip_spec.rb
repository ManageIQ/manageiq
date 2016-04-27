require "spec_helper"
require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/ConfigurationManagement/AnsibleTower/Operations/StateMachines/Job.class/__methods__/wait_for_ip').to_s
require Rails.root.join('spec/support/miq_ae_mock_service').to_s

describe WaitForIP do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:klass) { MiqAeMethodService::MiqAeServiceVm }
  let(:svc_vm) { klass.find(vm.id) }
  let(:ip_addr) { ['1.1.1.1'] }
  let(:svc_job) { job_class.find(job.id) }
  let(:root_object) { MiqAeMockObject.new }
  let(:service) { MiqAeMockService.new(root_object) }

  it "#main - ok" do
    root_object['vm'] = svc_vm
    allow_any_instance_of(klass).to receive(:ipaddresses).with(no_args).and_return(ip_addr)
    allow_any_instance_of(klass).to receive(:refresh).with(no_args).and_return(nil)

    WaitForIP.new(service).main

    expect(root_object['ae_result']).to eq('ok')
  end

  it "#main - retry" do
    root_object['vm'] = svc_vm
    allow_any_instance_of(klass).to receive(:ipaddresses).with(no_args).and_return([])
    allow_any_instance_of(klass).to receive(:refresh).with(no_args).and_return(nil)

    WaitForIP.new(service).main

    expect(root_object['ae_result']).to eq('retry')
  end
end
