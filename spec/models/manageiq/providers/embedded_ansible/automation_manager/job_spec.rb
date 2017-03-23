require 'support/ansible_shared/automation_manager/job'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job do
  let(:job) { FactoryGirl.create(:embedded_ansible_job) }

  it_behaves_like 'ansible job'

  it 'processes retire_now properly' do
    userid = 'freddy'
    expect(job).to receive(:finish_retirement).once
    job.retire_now(userid)
    expect(job.retirement_requester).to eq(userid)
  end
end
