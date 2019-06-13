describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential do
  let(:manager) do
    FactoryBot.create(:provider_embedded_ansible, :default_organization => 1).managers.first
  end

  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  context "#native_ref" do
    let(:simple_credential) { described_class.new(:manager_ref => '1', :resource => manager) }

    it "returns integer" do
      expect(simple_credential.manager_ref).to eq('1')
      expect(simple_credential.native_ref).to eq(1)
    end

    it "blows up for nil manager_ref" do
      simple_credential.manager_ref = nil
      expect(simple_credential.manager_ref).to be_nil
      expect { simple_credential.native_ref }.to raise_error(TypeError)
    end
  end

  # it_behaves_like 'ansible credential'
end
