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
