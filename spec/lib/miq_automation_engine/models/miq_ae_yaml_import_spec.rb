describe MiqAeYamlImport do
  let(:domain) { "domain" }
  let(:options) { {} }
  let(:miq_ae_yaml_import) { described_class.new(domain, options) }
  let(:options) { {"overwrite" => true, "tenant" => Tenant.root_tenant} }

  before do
    EvmSpecHelper.local_guid_miq_server_zone
  end

  describe "#new_domain_name_valid?" do
    context "when the options hash overwrite is true" do
      it "returns true" do
        expect(miq_ae_yaml_import.new_domain_name_valid?).to be_truthy
      end
    end
  end

  describe "transaction rollback" do
    context "#import" do
      let(:path) { "path" }
      it "old namespace is preserved" do
        dom = FactoryGirl.create(:miq_ae_domain, :name => domain)
        domain_yaml = {
          'object_type' => 'domain',
          'version'     => '1.0',
          'object'      => {'attributes' => dom.attributes}
        }
        ns = FactoryGirl.create(:miq_ae_namespace, :parent => dom)
        FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)

        allow(miq_ae_yaml_import).to receive(:domain_folder).with(domain).and_return(path)
        allow(miq_ae_yaml_import).to receive(:namespace_files).with(path) { raise ArgumentError }
        allow(miq_ae_yaml_import).to receive(:read_domain_yaml).with(path, domain) { domain_yaml }
        expect { miq_ae_yaml_import.import }.to raise_exception(ArgumentError)
        dom.reload
        expect(dom.ae_namespaces.first.id).to eq(ns.id)
      end
    end
  end
end
