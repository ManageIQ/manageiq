require "spec_helper"

describe EmsCloudHelper do
  before do
    controller.send(:extend, EmsCloudHelper)
    self.class.send(:include, EmsCloudHelper)
  end

  context "textual_instances" do
    def role_allows(_)
      true
    end

    it "sets restful path for instances in summary for restful controllers" do
      controller.stub(:restful?).and_return(true)
      controller.stub(:controller_name).and_return("ems_cloud")
      Zone.first || FactoryGirl.create(:zone)
      FactoryGirl.create(:ems_openstack, :zone => Zone.first)
      FactoryGirl.create(:vm_openstack)
      @ems = ManageIQ::Providers::Openstack::CloudManager.first
      vms = ManageIQ::Providers::Openstack::CloudManager::Vm.first
      vms.update_attributes(:ems_id => @ems.id)
      result = textual_instances
      expect(result[:link]).to eq("/ems_cloud/#{@ems.id}?display=instances")
    end
  end

  context "textual_images" do
    def role_allows(_)
      true
    end

    it "sets restful path for images in summary for restful controllers" do
      controller.stub(:restful?).and_return(true)
      controller.stub(:controller_name).and_return("ems_cloud")
      Zone.first || FactoryGirl.create(:zone)
      FactoryGirl.create(:ems_openstack, :zone => Zone.first)
      FactoryGirl.create(:template_cloud)
      @ems = ManageIQ::Providers::Openstack::CloudManager.first
      template = MiqTemplate.first
      template.update_attributes(:ems_id => @ems.id)
      result = textual_images
      expect(result[:link]).to eq("/ems_cloud/#{@ems.id}?display=images")
    end
  end
end
