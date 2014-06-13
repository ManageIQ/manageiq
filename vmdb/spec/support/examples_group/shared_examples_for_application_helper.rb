
shared_examples_for 'record without latest derived metrics' do |message|
  it "#{message}" do
    @record.stub(:latest_derived_metrics => false)
    subject.should == message
  end
end

shared_examples_for 'record without perf data' do |message|
  it "#{message}" do
    @record.stub(:has_perf_data? => false)
    subject.should == message
  end
end

shared_examples_for 'record without ems events and policy events' do |message|
  it "#{message}" do
    @record.stub(:has_events?).and_return(false)
    subject.should == message
  end
end

shared_examples_for 'record with error message' do |name|
  it "returns the #{name} error message" do
    message = "xx #{name} message"
    @record.stub(:is_available_now_error_message).with(name.to_sym).and_return(message)
    subject.should == message
  end
end

shared_examples_for 'default case' do
  it { should be_false }
end

shared_examples_for 'default true_case' do
  it { should be_true }
end

shared_examples_for 'vm not powered on' do |message|
  it "#{message}" do
    @record.stub(:current_state => 'off')
    subject.should == message
  end
end
