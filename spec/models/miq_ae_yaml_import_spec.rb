require "spec_helper"

describe MiqAeYamlImport do
  let(:domain) { "domain" }
  let(:options) { {} }
  let(:miq_ae_yaml_import) { described_class.new(domain, options) }

  describe "#new_domain_name_valid?" do
    context "when the options hash overwrite is true" do
      let(:options) { {"overwrite" => true} }

      it "returns true" do
        expect(miq_ae_yaml_import.new_domain_name_valid?).to be_true
      end
    end
  end
end
