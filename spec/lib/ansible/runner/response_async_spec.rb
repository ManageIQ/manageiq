RSpec.describe Ansible::Runner::ResponseAsync do
  subject { described_class.new(:base_dir => "fake") }

  it "serializes through dump and load" do
    allow(AwesomeSpawn).to receive(:run).and_return(double(:success? => false))
    described_class.load(subject.dump)
  end
end
