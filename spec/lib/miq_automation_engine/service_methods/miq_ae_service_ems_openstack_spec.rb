
require "spec_helper"

module MiqAeServiceEmsOpenstackSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceEmsOpenstack do

    before(:each) do
      @ems                    = FactoryGirl.create(:ems_openstack)
      @flavor                 = FactoryGirl.create(:flavor)
      @availability_zone      = FactoryGirl.create(:availability_zone)
      @ems.availability_zones << @availability_zone
      @ems.flavors            << @flavor
      @ems_openstack          = MiqAeMethodService::MiqAeServiceEmsOpenstack.find(@ems.id)
    end

    it "#flavors" do
      flavor = @ems_openstack.flavors.first
      flavor.should be_kind_of(MiqAeMethodService::MiqAeServiceFlavor)
    end

    it "#availability_zones" do
      availability_zone = @ems_openstack.availability_zones.first
      availability_zone.should be_kind_of(MiqAeMethodService::MiqAeServiceAvailabilityZone)
    end
  end
end
