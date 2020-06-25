RSpec.describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job::Status do
  # The following specs are copied from the 'ansible job status' spec helper
  # from the AnsibleTower Provider repo, but have been modified to make sense
  # for the case of AnsibleRunner implementation.  Previously was:
  #
  # it_behaves_like 'ansible job status'

  let(:miq_task) { MiqTask.new(:state => MiqTask::STATE_FINISHED) }

  it 'parses Succeeded' do
    miq_task.status = MiqTask::STATUS_OK
    status          = described_class.new(miq_task, '')

    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_truthy
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(['create_complete', ''])
  end

  it 'parses Failed' do
    miq_task.status = MiqTask::STATUS_ERROR
    status          = described_class.new(miq_task, nil)

    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_truthy
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(['failed', 'Stack creation failed'])
  end

  it 'parses transient status' do
    miq_task.state  = MiqTask::STATE_ACTIVE
    miq_task.status = MiqTask::STATUS_UNKNOWN
    status          = described_class.new(miq_task, nil)

    expect(status.completed?).to   be_falsey
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(%w[transient Active])
  end
end
