
require "spec_helper"

module MiqAeServiceEmsAmazonSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceEmsAmazon do

    before(:each) do
      @ems                    = FactoryGirl.create(:ems_amazon)
      @flavor                 = FactoryGirl.create(:flavor)
      @availability_zone      = FactoryGirl.create(:availability_zone)
      @ems.availability_zones << @availability_zone
      @ems.flavors            << @flavor
      @ems_amazon             = MiqAeMethodService::MiqAeServiceEmsAmazon.find(@ems.id)
    end

    it "#flavors" do
      flavor = @ems_amazon.flavors.first
      flavor.should be_kind_of(MiqAeMethodService::MiqAeServiceFlavor)
    end

    it "#availability_zones" do
      availability_zone = @ems_amazon.availability_zones.first
      availability_zone.should be_kind_of(MiqAeMethodService::MiqAeServiceAvailabilityZone)
    end
  end
end
