require "spec_helper"

describe EmsCloudHelper::TextualSummary do
  context "#textual_instances and #textual_images" do
    before do
      @ems = FactoryGirl.create(:ems_openstack, :zone => FactoryGirl.build(:zone))
      allow_any_instance_of(described_class).to receive(:role_allows).and_return(true)
      allow(controller).to receive(:restful?).and_return(true)
      allow(controller).to receive(:controller_name).and_return("ems_cloud")
    end

    it "sets restful path for instances in summary for restful controllers" do
      FactoryGirl.create(:vm_openstack, :ems_id => @ems.id)

      expect(textual_instances[:link]).to eq("/ems_cloud/#{@ems.id}?display=instances")
    end

    it "sets restful path for images in summary for restful controllers" do
      FactoryGirl.create(:template_cloud, :ems_id => @ems.id)

      expect(textual_images[:link]).to eq("/ems_cloud/#{@ems.id}?display=images")
    end
  end
end
