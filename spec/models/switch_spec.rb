RSpec.describe Switch do
  let(:ems)    { FactoryBot.create(:ext_management_system) }
  let(:host)   { FactoryBot.create(:host, :ext_management_system => ems) }
  let(:switch) { FactoryBot.create(:switch, :host => host) }

  it "#ext_management_system" do
    expect(switch.ext_management_system).to eq(ems)
  end
end
