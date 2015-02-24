require "spec_helper"

describe MiqRegion do
  REGION_FILE = File.join(Rails.root, "REGION")
  def read_region
    (File.open(REGION_FILE, 'r') {|f| f.read }).chomp if File.exist?(REGION_FILE)
  end

  def write_region(number)
    File.open(REGION_FILE, 'w') {|f| f.write(number) } if File.exist?(REGION_FILE)
  end

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
    end

    context "existing region" do
      before(:each) do
        @region = FactoryGirl.create(:miq_region, :region => @region_number)
        @other_region = FactoryGirl.create(:miq_region, :region => @region_number + 1)
      end

      context "after seeding" do
        before(:each) do
          MiqRegion.seed
        end

        it "should find region" do
          MiqRegion.exists?(:region => @region_number).should be_true
        end
      end

      context "then original destroyed" do
        before(:each) do
          @region.destroy
        end

        it "should not find region" do
          MiqRegion.exists?(:region => @region_number).should_not be_true
        end

        context "after seeding" do
          before(:each) do
            MiqRegion.seed
          end

          it "should find region" do
            MiqRegion.exists?(:region => @region_number).should be_true
          end
        end
      end

      context "with MiqDatabase" do
        before(:each) do
          @db = FactoryGirl.create(:miq_database)
        end

        it "will raise Exception if my_region_number is not the db region" do
          MiqRegion.stub(:my_region_number).and_return(@other_region.region)
          MiqRegion.my_region_number.should_not == @db.region_id
          lambda { MiqRegion.seed }.should raise_error(Exception)
        end
      end
    end
  end
end
