describe ManageIQ::Providers::Vmware::InfraManager::Template do
  context "supports_clone?" do
    let(:template_vmware) { ManageIQ::Providers::Vmware::InfraManager::Template.new }

    it "returns true" do
      expect(template_vmware.supports?(:clone)).to eq(true)
    end
  end
end
