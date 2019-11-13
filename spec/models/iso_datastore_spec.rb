describe IsoDatastore do
  let(:ems) { FactoryBot.create(:ems_redhat) }
  let(:iso_datastore) { FactoryBot.create(:iso_datastore, :ext_management_system => ems) }

  describe "#advertised_images" do
    subject(:advertised_images) { iso_datastore.advertised_images }

    context "ems is not rhv" do
      let(:ems) { FactoryBot.create(:ems_vmware) }
      it "returns empty array" do
        expect(advertised_images).to eq([])
      end
    end

    context "ems is rhv" do
      before do
        allow(ems).to receive(:supported_api_versions).and_return(supported_api_versions)
      end

      context "supports api4" do
        let(:supported_api_versions) { %w(3 4) }
        it "send the method to ovirt services v4" do
          expect_any_instance_of(ManageIQ::Providers::Redhat::InfraManager::OvirtServices::V4)
            .to receive(:advertised_images)
          advertised_images
        end
      end
    end
  end
end
