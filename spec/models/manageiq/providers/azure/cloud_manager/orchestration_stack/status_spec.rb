require "spec_helper"

describe ManageIQ::Providers::Azure::CloudManager::OrchestrationStack::Status do
  it 'parses Succeeded' do
    status = described_class.new('Succeeded', '')
    status.completed?.should   be_true
    status.succeeded?.should   be_true
    status.failed?.should      be_false
    status.deleted?.should     be_false
    status.rolled_back?.should be_false
    status.normalized_status.should == ['create_complete', '']
  end

  it 'parses Failed' do
    status = described_class.new('Failed', nil)
    status.completed?.should   be_true
    status.succeeded?.should   be_false
    status.failed?.should      be_true
    status.deleted?.should     be_false
    status.rolled_back?.should be_false
    status.normalized_status.should == ['failed', 'Stack creation failed']
  end

  it 'parses Deleted' do
    status = described_class.new('Deleted', nil)
    status.completed?.should   be_true
    status.succeeded?.should   be_false
    status.failed?.should      be_false
    status.deleted?.should     be_true
    status.rolled_back?.should be_false
    status.normalized_status.should == ['delete_complete', 'Stack was deleted']
  end

  it 'parses Canceled' do
    status = described_class.new('Canceled', nil)
    status.completed?.should   be_true
    status.succeeded?.should   be_false
    status.canceled?.should    be_true
    status.deleted?.should     be_false
    status.rolled_back?.should be_false
    status.normalized_status.should == ['create_canceled', 'Stack creation was canceled']
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
