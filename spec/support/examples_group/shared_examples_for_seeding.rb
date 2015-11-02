shared_examples_for ".seed called multiple times" do |count = 1|
  it ".seed called multiple times" do
    3.times { described_class.seed }
    expect(described_class.count).to eq(count)
  end
end
