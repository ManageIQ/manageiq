require "spec_helper"

describe MiqRegion do
  context "after seeding" do
    before(:each) do
      MiqRegion.seed
    end

    it "should increment naming sequence number after each call" do
      MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming").should == 1
      MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming").should == 2
      MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming").should == 1
      MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming").should == 2
    end

    context "with cloud and infra EMSes" do

      before :each do
        guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
        ems_vmware = FactoryGirl.create(:ems_vmware, :zone => zone)
        ems_openstack = FactoryGirl.create(:ems_openstack, :zone => zone)
        ems_redhat = FactoryGirl.create(:ems_redhat, :zone => zone)

        @ems_clouds = [ems_openstack]
        @ems_infras = [ems_redhat, ems_vmware]

        @region = MiqRegion.my_region
      end

      it "should be able to return the list of ems_clouds" do
        @region.ems_clouds.should include(*@ems_clouds)
        @region.ems_clouds.should_not include(*@ems_infras)
      end

      it "should be able to return the list of ems_infras" do
        @region.ems_infras.should include(*@ems_infras)
        @region.ems_infras.should_not include(*@ems_clouds)
      end
    end
  end

  context ".seed" do
    before do
      @region_number = 99
      MiqRegion.stub(:my_region_number => @region_number)
    end

    context "no regions" do
      before(:each) do
        MiqRegion.seed
      end

      it "seeds 1 record in the miq_regions" do
        MiqRegion.count.should == 1
        MiqRegion.first.region.should == @region_number
      end

      it "skips seeding if one exists" do
        MiqRegion.seed
        MiqRegion.count.should == 1
        MiqRegion.first.region.should == @region_number
      end

      it "replaces deleted current region" do
        MiqRegion.where(:region => @region_number).destroy_all
        MiqRegion.count.should == 0
        MiqRegion.seed
        MiqRegion.first.region.should == @region_number
      end
    end

    it "raises Exception if db region_id doesn't match my_region_number" do
      FactoryGirl.create(:miq_region, :region => @region_number)
      @db = FactoryGirl.create(:miq_database)
      MiqRegion.stub(:my_region_number => @region_number + 1)
      lambda { MiqRegion.seed }.should raise_error(Exception)
    end
  end
end
