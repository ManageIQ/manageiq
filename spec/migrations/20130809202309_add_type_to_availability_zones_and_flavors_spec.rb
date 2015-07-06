require "spec_helper"
require Rails.root.join("db/migrate/20130809202309_add_type_to_availability_zones_and_flavors.rb")

describe AddTypeToAvailabilityZonesAndFlavors do
  migration_context :up do
    let(:ems_stub)    { migration_stub(:ExtManagementSystem) }
    let(:az_stub)     { migration_stub(:AvailabilityZone) }
    let(:flavor_stub) { migration_stub(:Flavor) }

    before do
      @ems_amazon    = ems_stub.create!(:type => "EmsAmazon")
      @ems_openstack = ems_stub.create!(:type => "EmsOpenstack")
    end

    it "migrates type column for availability_zones" do
      az_amazon     = az_stub.create!(:ems_id => @ems_amazon.id)
      az_openstack  = az_stub.create!(:ems_id => @ems_openstack.id)

      migrate

      az_amazon.reload.type.should    == "AvailabilityZoneAmazon"
      az_openstack.reload.type.should == "AvailabilityZoneOpenstack"
    end

    it "migrates type column for flavors" do
      flavor_amazon    = flavor_stub.create!(:ems_id => @ems_amazon.id)
      flavor_openstack = flavor_stub.create!(:ems_id => @ems_openstack.id)

      migrate

      flavor_amazon.reload.type.should    == "FlavorAmazon"
      flavor_openstack.reload.type.should == "FlavorOpenstack"
    end
  end
end
