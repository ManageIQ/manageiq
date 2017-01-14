
module MiqAeServiceAvailabilityZoneSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceAvailabilityZone do
    before(:each) do
      @availability_zone          = FactoryGirl.create(:availability_zone, :name => "us-west-1a")
      @service_availability_zone  = MiqAeMethodService::MiqAeServiceAvailabilityZone.find(@availability_zone.id)
    end

    it "check values" do
      expect(@service_availability_zone.name).to eq("us-west-1a")
      expect(@service_availability_zone).to be_kind_of(MiqAeMethodService::MiqAeServiceAvailabilityZone)
    end

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end

    it "#vms_and_templates" do
      expect(described_class.instance_methods).to include(:vms_and_templates)
    end

    it "#cloud_subnets" do
      expect(described_class.instance_methods).to include(:cloud_subnets)
    end
  end
end
