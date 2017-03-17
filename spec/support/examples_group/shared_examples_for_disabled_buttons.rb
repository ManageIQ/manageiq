shared_examples_for 'a disabled button' do |err_msg|
  subject { button }
  it do
    expect(subject[:enabled]).to be_falsey
  end
end
