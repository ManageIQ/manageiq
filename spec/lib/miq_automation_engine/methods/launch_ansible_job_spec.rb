require "spec_helper"
require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/ConfigurationManagement/AnsibleTower/Operations/StateMachines/Job.class/__methods__/launch_ansible_job').to_s
require Rails.root.join('spec/support/miq_ae_mock_service').to_s

describe LaunchAnsibleJob do
  let(:job_class) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager_Job }
  let(:jt_class) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager_ConfigurationScript }
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:svc_vm) { MiqAeMethodService::MiqAeServiceVm.find(vm.id) }
  let(:job_template) { FactoryGirl.create(:ansible_configuration_script) }
  let(:svc_job_template) { jt_class.find(job_template.id) }
  let(:ip_addr) { '1.1.1.1' }
  let(:job) { FactoryGirl.create(:ansible_tower_job) }
  let(:svc_job) { job_class.find(job.id) }
  let(:current_object) { MiqAeMockObject.new('a' => 1, 'b' => 2) }
  let(:root_object) { MiqAeMockObject.new('param1' => "x=X", 'param2' => "y=Y") }
  let(:middle_object) { MiqAeMockObject.new('a' => 1, 'b' => 2) }

  let(:ext_vars) { {'x' => 'X', 'y' => 'Y'} }
  let(:job_args) { {:extra_vars => ext_vars} }

  let(:service) { MiqAeMockService.new(root_object) }

  it "run a job using job template name" do
    root_object['vm'] = svc_vm
    current_object = MiqAeMockObject.new(:job_template_name => job_template.name)
    current_object.parent = root_object
    service.object = current_object
    job_args[:limit] = vm.name
    expect(job_class).to receive(:create_job).with(anything, job_args).and_return(svc_job)
    LaunchAnsibleJob.new(service).main
    expect(service.get_state_var(:ansible_job_id)).to eq(job.id)
  end

  it "run a job using job template id" do
    root_object['vm'] = svc_vm
    current_object = MiqAeMockObject.new(:job_template_id => job_template.id)
    current_object.parent = root_object
    service.object = current_object
    job_args[:limit] = vm.name
    expect(job_class).to receive(:create_job).with(anything, job_args).and_return(svc_job)
    LaunchAnsibleJob.new(service).main
    expect(service.get_state_var(:ansible_job_id)).to eq(job.id)
  end

  it "run a job using job template object" do
    root_object['vm'] = svc_vm
    current_object = MiqAeMockObject.new(:job_template => svc_job_template)
    current_object.parent = root_object
    service.object = current_object
    job_args[:limit] = vm.name
    expect(job_class).to receive(:create_job).with(anything, job_args).and_return(svc_job)
    LaunchAnsibleJob.new(service).main
    expect(service.get_state_var(:ansible_job_id)).to eq(job.id)
  end

  it "extra vars from current object" do
    root_object['vm'] = svc_vm
    root_object[:job_template_name] = job_template.name
    ext_vars['x'] = '1'
    ext_vars['y'] = '2'
    job_args[:limit] = vm.name
    current_object = MiqAeMockObject.new('param1' => 'x=1', 'param2' => 'y=2')
    current_object.parent = root_object
    service.object = current_object
    expect(job_class).to receive(:create_job).once.with(anything, job_args).and_return(svc_job)
    LaunchAnsibleJob.new(service).main
    expect(service.get_state_var(:ansible_job_id)).to eq(job.id)
  end

  it "use limit from job template" do
    root_object[:job_template_name] = job_template.name
    ext_vars['x'] = '1'
    ext_vars['y'] = '2'
    current_object = MiqAeMockObject.new('param1' => 'x=1', 'param2' => 'y=2')
    current_object.parent = root_object
    service.object = current_object
    expect(job_class).to receive(:create_job).once.with(anything, job_args).and_return(svc_job)
    LaunchAnsibleJob.new(service).main
    expect(service.get_state_var(:ansible_job_id)).to eq(job.id)
  end
end
