require "spec_helper"

describe ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status do
  it 'parses CREATE_COMPLETE' do
    status = described_class.new('CREATE_COMPLETE', '')
    status.completed?.should   be_true
    status.succeeded?.should   be_true
    status.failed?.should      be_false
    status.deleted?.should     be_false
    status.rolled_back?.should be_false
    status.normalized_status.should == ['create_complete', '']
  end

  it 'parses ROLLBACK_COMPLETE' do
    status = described_class.new('ROLLBACK_COMPLETE', nil)
    status.completed?.should   be_true
    status.succeeded?.should   be_false
    status.failed?.should      be_false
    status.deleted?.should     be_false
    status.rolled_back?.should be_true
    status.normalized_status.should == ['rollback_complete', 'Stack was rolled back']
  end

  it 'parses DELETE_COMPLETE' do
    status = described_class.new('DELETE_COMPLETE', nil)
    status.completed?.should   be_true
    status.succeeded?.should   be_false
    status.failed?.should      be_false
    status.deleted?.should     be_true
    status.rolled_back?.should be_false
    status.normalized_status.should == ['delete_complete', 'Stack was deleted']
  end

  it 'parses ROLLBACK_FAILED' do
    status = described_class.new('ROLLBACK_FAILED', nil)
    status.completed?.should   be_true
    status.succeeded?.should   be_false
    status.failed?.should      be_true
    status.deleted?.should     be_false
    status.rolled_back?.should be_false
    status.normalized_status.should == ['failed', 'Stack creation failed']
  end

  it 'parses transient status' do
    status = described_class.new('CREATING', nil)
    status.completed?.should   be_false
    status.succeeded?.should   be_false
    status.failed?.should      be_false
    status.deleted?.should     be_false
    status.rolled_back?.should be_false
    status.normalized_status.should == %w(transient CREATING)
  end
end
