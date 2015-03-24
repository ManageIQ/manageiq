require "spec_helper"

describe VmReconfigureRequest do
  before do
    @guid1 = MiqUUID.new_guid
    @zone1 = FactoryGirl.create(:zone, :name => "zone_1")
    FactoryGirl.create(:miq_server_master, :guid => @guid1, :zone => @zone1)
    @request = FactoryGirl.create(:vm_reconfigure_request, :userid => FactoryGirl.create(:user, :userid => "tester").userid)

    guid2   = MiqUUID.new_guid
    @zone2  = FactoryGirl.create(:zone, :name => "zone_2")
    FactoryGirl.create(:miq_server, :guid => guid2, :zone => @zone2)
    @vm = FactoryGirl.create(:vm_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware, :zone => @zone2))
  end

  describe '#my_role' do
    it "should be 'ems_operations'" do
      @request.my_role.should == 'ems_operations'
    end
  end

  describe '#my_zone' do
    context 'with valid sources' do
      before { @request.update_attributes(:options => {:src_ids => [@vm.id]}) }

      it "shoud be the same as VM's zone" do
        @request.my_zone.should eq(@vm.my_zone)
      end

      it "should not be the same as the request's zone" do
        @request.my_zone.should_not eq(@zone1.name)
      end
    end

    context "with no source" do
      it "should be the same as the request's zone" do
        @request.update_attributes(:options => {})
        MiqServer.stub(:my_guid).and_return(@guid1)
        @request.my_zone.should eq(@zone1.name)
      end
    end
  end
end
