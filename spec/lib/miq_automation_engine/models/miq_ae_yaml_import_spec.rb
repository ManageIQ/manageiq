describe MiqAeYamlImport do
  let(:domain) { "domain" }
  let(:options) { {} }
  let(:miq_ae_yaml_import) { described_class.new(domain, options) }

  before do
    EvmSpecHelper.local_guid_miq_server_zone
  end

  describe "#new_domain_name_valid?" do
    context "when the options hash overwrite is true" do
      let(:options) { {"overwrite" => true, "tenant" => Tenant.root_tenant} }

      it "returns true" do
        expect(miq_ae_yaml_import.new_domain_name_valid?).to be_truthy
      end
    end
  end
end
