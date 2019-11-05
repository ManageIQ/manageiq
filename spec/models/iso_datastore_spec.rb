describe IsoDatastore do
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
      let(:ems) { FactoryBot.create(:ems_redhat, :api_version => '4.3.6') }

      context "supports api4" do
        it "send the method to ovirt services v4" do
          expect_any_instance_of(ManageIQ::Providers::Redhat::InfraManager::OvirtServices::V4)
            .to receive(:advertised_images)
          advertised_images
        end
      end
    end
  end
end
