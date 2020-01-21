RSpec.describe IsoDatastore do
  let(:ems) { FactoryBot.create(:ems_redhat) }
  let(:iso_datastore) { FactoryBot.create(:iso_datastore, :ext_management_system => ems) }

  context "queued methods" do
    it 'queues a sync task with synchronize_advertised_images_queue' do
      queue = iso_datastore.synchronize_advertised_images_queue

      expect(queue).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'synchronize_advertised_images',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => []
      )
    end
  end

  describe "#advertised_images" do
    subject(:advertised_images) { iso_datastore.advertised_images }

    context "ems is not rhv" do
      let(:ems) { FactoryBot.create(:ems_vmware) }
      it "returns empty array" do
        expect(advertised_images).to eq([])
      end
    end

    context "ems is rhv" do
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
