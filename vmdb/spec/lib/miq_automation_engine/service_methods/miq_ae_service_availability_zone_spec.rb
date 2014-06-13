
require "spec_helper"

module MiqAeServiceAvailabilityZoneSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceAvailabilityZone do

    before(:each) do
      @availability_zone          = FactoryGirl.create(:availability_zone, :name => "us-west-1a")
      @service_availability_zone  = MiqAeMethodService::MiqAeServiceAvailabilityZone.find(@availability_zone.id)
    end

    it "check values" do
      @service_availability_zone.name.should == "us-west-1a"
      @service_availability_zone.should be_kind_of(MiqAeMethodService::MiqAeServiceAvailabilityZone)
    end
  end
end
