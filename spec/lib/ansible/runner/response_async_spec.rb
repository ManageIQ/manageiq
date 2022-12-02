RSpec.describe Ansible::Runner::ResponseAsync do
  subject { described_class.new(:base_dir => "/path/to/results") }

  it "#dump" do
    expect(subject.dump).to eq(
      :base_dir => "/path/to/results",
      :debug    => false,
      :ident    => "result"
    )
  end

  it ".load" do
    response = described_class.load(subject.dump)

    expect(response).to be_a(described_class)
    expect(response.base_dir).to eq("/path/to/results")
  end
end
