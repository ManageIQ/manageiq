RSpec.describe ConfigurationLocation do
  it { expect(described_class.new(:title => "x").display_name).to eq("x") }
end
