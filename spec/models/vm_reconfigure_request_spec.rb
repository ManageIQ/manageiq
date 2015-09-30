require "spec_helper"

describe VmReconfigureRequest do
  let(:admin) { FactoryGirl.create(:user, :userid => "tester") }
  before do
    server = FactoryGirl.create(:miq_server, :is_master => true)
    @request = FactoryGirl.create(:vm_reconfigure_request, :userid => admin.userid)
    @guid1 = server.guid
    @zone1 = server.zone

    zone2  = FactoryGirl.create(:zone, :name => "zone_2")
    FactoryGirl.create(:miq_server, :zone => zone2)
    @vm = FactoryGirl.create(:vm_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware, :zone => zone2))
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

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_reconfigure_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Reconfigure requested by <#{admin.userid}> for Vm:#{[@vm.id].inspect}"
      )

      # creates a request
      stub_get_next_vm_name

      # the dialogs populate this
      values = {:src_ids => [@vm.id]}

      request = described_class.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(described_class)
      expect(request.request_type).to eq("vm_reconfigure")
      expect(request.description).to eq("VM Reconfigure for: #{@vm.name} - ")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_reconfigure_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Reconfigure request updated by <#{alt_user.userid}> for Vm:#{[@vm.id].inspect}"
      )
      described_class.make_request(request, values, alt_user.userid)
    end
  end

  def stub_get_next_vm_name(vm_name = "New VM")
    allow(MiqProvision).to receive(:get_next_vm_name).and_return(vm_name)
  end
end
