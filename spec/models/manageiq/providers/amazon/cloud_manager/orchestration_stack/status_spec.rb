describe ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status do
  it 'parses CREATE_COMPLETE' do
    status = described_class.new('CREATE_COMPLETE', '')
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_truthy
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.updated?).to     be_falsey
    expect(status.normalized_status).to eq(['create_complete', ''])
  end

  it 'parses ROLLBACK_COMPLETE' do
    status = described_class.new('ROLLBACK_COMPLETE', nil)
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_truthy
    expect(status.updated?).to     be_falsey
    expect(status.normalized_status).to eq(['rollback_complete', 'Stack was rolled back'])
  end

  it 'parses DELETE_COMPLETE' do
    status = described_class.new('DELETE_COMPLETE', nil)
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_truthy
    expect(status.rolled_back?).to be_falsey
    expect(status.updated?).to     be_falsey
    expect(status.normalized_status).to eq(['delete_complete', 'Stack was deleted'])
  end

  it 'parses ROLLBACK_FAILED' do
    status = described_class.new('ROLLBACK_FAILED', nil)
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_truthy
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.updated?).to     be_falsey
    expect(status.normalized_status).to eq(['failed', 'Stack creation failed'])
  end

  it 'parses UPDATE_COMPLETE' do
    status = described_class.new('UPDATE_COMPLETE', nil)
    expect(status.completed?).to   be_truthy
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.updated?).to     be_truthy
    expect(status.normalized_status).to eq(%w(update_complete OK))
  end

  it 'parses transient status' do
    status = described_class.new('CREATING', nil)
    expect(status.completed?).to   be_falsey
    expect(status.succeeded?).to   be_falsey
    expect(status.failed?).to      be_falsey
    expect(status.deleted?).to     be_falsey
    expect(status.rolled_back?).to be_falsey
    expect(status.updated?).to     be_falsey
    expect(status.normalized_status).to eq(%w(transient CREATING))
  end
end
