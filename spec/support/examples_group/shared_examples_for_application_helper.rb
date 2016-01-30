
shared_examples_for 'record without latest derived metrics' do |message|
  it "#{message}" do
    allow(@record).to receive_messages(:latest_derived_metrics => false)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'record without perf data' do |message|
  it "#{message}" do
    allow(@record).to receive_messages(:has_perf_data? => false)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'record without ems events and policy events' do |message|
  it "#{message}" do
    allow(@record).to receive(:has_events?).and_return(false)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'record with error message' do |name|
  it "returns the #{name} error message" do
    message = "xx #{name} message"
    allow(@record).to receive(:is_available_now_error_message).with(name.to_sym).and_return(message)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'default case' do
  it { is_expected.to be_falsey }
end

shared_examples_for 'default true_case' do
  it { is_expected.to be_truthy }
end

shared_examples_for 'vm not powered on' do |message|
  it "#{message}" do
    allow(@record).to receive_messages(:current_state => 'off')
    expect(subject).to eq(message)
  end
end
