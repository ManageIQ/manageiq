RSpec.describe HostInitiatorGroup do
  context "basics" do
    let(:host_initiator_group) { FactoryBot.create(:host_initiator_group) }
    let(:host_initiator) { FactoryBot.create(:host_initiator) }

    it "Reflects SAN addressees of its child host-initiators" do
      expect(host_initiator_group.san_addresses.count).to eq(0)

      host_initiator.host_initiator_group = host_initiator_group
      host_initiator.save

      expect(host_initiator_group.san_addresses.count).to eq(1)
      expect(host_initiator_group.san_addresses.first).to eq(host_initiator.san_addresses.first)
    end
  end
end
