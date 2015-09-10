require "spec_helper"

describe TextualSummaryHelper do
  before do
    controller.send(:extend, TextualSummaryHelper)
    self.class.send(:include, TextualSummaryHelper)
  end

  context "textual_collection_link" do
    def role_allows(_)
      true
    end

    it "uses the restful path to retrieve the summary screen link for a restful controller" do
      controller.stub(:restful?).and_return(true)
      controller.stub(:controller_name).and_return("ems_cloud")
      Zone.first || FactoryGirl.create(:zone)
      FactoryGirl.create(:ems_openstack, :zone => Zone.first)
      FactoryGirl.create(:availability_zone_openstack)
      ems = ManageIQ::Providers::Openstack::CloudManager.first
      az = AvailabilityZone.first
      az.update_attributes(:ems_id => ems.id)
      result = textual_collection_link(ems.availability_zones)
      expect(result[:link]).to eq("/ems_cloud/#{ems.id}?display=availability_zones")
    end

    it "uses the controller-action-id path to retrieve the summary screen link for a non-restful controller" do
      controller.stub(:restful?).and_return(false)
      controller.stub(:controller_name).and_return("ems_infra")
      Zone.first || FactoryGirl.create(:zone)
      FactoryGirl.create(:ems_openstack, :zone => Zone.first)
      FactoryGirl.create(:availability_zone_openstack)
      ems = ManageIQ::Providers::Openstack::CloudManager.first
      az = AvailabilityZone.first
      az.update_attributes(:ems_id => ems.id)
      result = textual_collection_link(ems.availability_zones)
      expect(result[:link]).to eq("/ems_infra/show/#{ems.id}?display=availability_zones")
    end
  end
end
