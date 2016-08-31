
shared_examples_for 'record without latest derived metrics' do |message|
  it message.to_s do
    allow(@record).to receive_messages(:latest_derived_metrics => false)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'record without perf data' do |message|
  it message.to_s do
    allow(@record).to receive_messages(:has_perf_data? => false)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'record without ems events and policy events' do |message|
  it message.to_s do
    allow(@record).to receive(:has_events?).and_return(false)
    expect(subject).to eq(message)
  end
end

shared_examples_for 'record with error message' do |name|
  it "returns the #{name} error message" do
    message = "xx #{name} message"
    if @record.respond_to?("supports_#{name.to_sym}?")
      allow(@record).to receive(:unsupported_reason).with(name.to_sym).and_return(message)
    else
      allow(@record).to receive(:is_available_now_error_message).with(name.to_sym).and_return(message)
    end
    expect(subject).to eq(message)
  end
end

shared_examples_for 'default case' do
  it { is_expected.to be_falsey }
end

shared_examples_for 'default true_case' do
  it { is_expected.to be_truthy }
end

shared_examples_for 'will be skipped for this record' do |message|
  it message.to_s do
    view_context = setup_view_context_with_sandbox({})
    button = described_class.new(view_context, {}, {'record' => @record}, {})
    expect(button.visible?).to be_falsey
  end
end

shared_examples_for 'will not be skipped for this record' do |message|
  it message.to_s do
    view_context = setup_view_context_with_sandbox({})
    button = described_class.new(view_context, {}, {'record' => @record}, {})
    expect(button.visible?).to be_truthy
  end
end

shared_examples_for 'vm not powered on' do |message|
  it message.to_s do
    allow(@record).to receive_messages(:current_state => 'off')
    expect(subject).to eq(message)
  end
end

shared_examples_for 'when record is archived' do |message|
  it "#{message} will be skipped" do
    view_context = setup_view_context_with_sandbox({})
    record = FactoryGirl.create(:vm_microsoft)
    allow(record).to receive(:archived?).and_return(true)
    button = described_class.new(view_context, {}, {'record' => record}, {})
    expect(button.visible?).to be_falsey
  end
end

shared_examples_for 'when record is orphaned' do |message|
  it "#{message} will be skipped" do
    view_context = setup_view_context_with_sandbox({})
    record = FactoryGirl.create(:vm_microsoft)
    allow(record).to receive(:orphaned?).and_return(true)
    button = described_class.new(view_context, {}, {'record' => record}, {})
    expect(button.visible?).to be_falsey
  end
end
