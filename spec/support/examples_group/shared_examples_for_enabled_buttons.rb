shared_examples_for 'an enabled button' do
  subject { button }
  it do
    expect(subject[:enabled]).to be_truthy
  end
end
