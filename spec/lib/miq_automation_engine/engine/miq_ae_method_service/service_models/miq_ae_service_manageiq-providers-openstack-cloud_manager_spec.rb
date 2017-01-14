
module MiqAeServiceEmsOpenstackSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager do
    before(:each) do
      @ems                    = FactoryGirl.create(:ems_openstack)
      @flavor                 = FactoryGirl.create(:flavor_openstack)
      @availability_zone      = FactoryGirl.create(:availability_zone_openstack)
      @ems.availability_zones << @availability_zone
      @ems.flavors << @flavor
      @ems_openstack          = MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager.find(@ems.id)
    end

    it "#flavors" do
      flavor = @ems_openstack.flavors.first
      expect(flavor).to be_kind_of(MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Flavor)
    end

    it "#availability_zones" do
      availability_zone = @ems_openstack.availability_zones.first
      expect(availability_zone).to be_kind_of(MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_AvailabilityZone)
    end

    it "#create_host_aggregate" do
      expect(described_class.instance_methods).to include(:create_host_aggregate)
    end
  end
end
