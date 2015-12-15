require 'spec_helper'

describe 'task_finished method' do
  let(:miq_server)       { EvmSpecHelper.local_miq_server }
  let(:user)             { FactoryGirl.create(:user_with_email_and_group) }
  let(:miq_request_task) { FactoryGirl.create(:miq_request_task, :miq_request => request, :source => vm) }
  let(:request)          { FactoryGirl.create(:vm_migrate_request, :requester => user) }

  let(:ems)              { FactoryGirl.create(:ems_vmware, :tenant => Tenant.root_tenant) }
  let(:vm)               { FactoryGirl.create(:vm_vmware, :ems_id => ems.id, :evm_owner => user) }

  it 'resets task status' do
    miq_request_task.update_attributes(:state => 'finished', :status => 'Error', :message => 'timed out after 600.282732 seconds.  Timeout threshold [600]')
    attrs = ["MiqServer::miq_server=#{miq_server.id}"]
    attrs << "MiqRequestTask::vm_migrate_task=#{miq_request_task.id}"
    MiqAeEngine.instantiate("/System/CommonMethods/StateMachineMethods/vm_migrate_finished?#{attrs.join('&')}", user)
    expect(miq_request_task.reload.status).to eq('Ok')
  end
end
