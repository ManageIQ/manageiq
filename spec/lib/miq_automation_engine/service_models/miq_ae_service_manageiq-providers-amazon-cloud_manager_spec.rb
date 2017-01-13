
module MiqAeServiceManageIQ_Providers_Amazon_CloudManagerSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Amazon_CloudManager do
    before(:each) do
      @ems                    = FactoryGirl.create(:ems_amazon)
      @flavor                 = FactoryGirl.create(:flavor)
      @availability_zone      = FactoryGirl.create(:availability_zone)
      @ems.availability_zones << @availability_zone
      @ems.flavors << @flavor
      @ems_amazon             = MiqAeMethodService::MiqAeServiceManageIQ_Providers_Amazon_CloudManager.find(@ems.id)
    end

    it "#flavors" do
      flavor = @ems_amazon.flavors.first
      expect(flavor).to be_kind_of(MiqAeMethodService::MiqAeServiceFlavor)
    end

    it "#availability_zones" do
      availability_zone = @ems_amazon.availability_zones.first
      expect(availability_zone).to be_kind_of(MiqAeMethodService::MiqAeServiceAvailabilityZone)
    end
  end
end
