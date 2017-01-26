describe ManageIQ::Providers::AnsibleTower::AutomationManager::Job::Status do
  it 'parses Succeeded' do
    status = described_class.new('Successful', '')
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_truthy
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(['create_complete', ''])
  end

  it 'parses Failed' do
    status = described_class.new('Failed', nil)
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_truthy
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(['failed', 'Job launching failed'])
  end

  it 'parses Canceled' do
    status = described_class.new('Canceled', nil)
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.canceled?).to    be_truthy
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(['create_canceled', 'Job launching was canceled'])
  end

  it 'parses transient status' do
    status = described_class.new('Running', nil)
    expect(status.completed?).to   be_falsey
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.normalized_status).to eq(%w(transient Running))
  end
end
