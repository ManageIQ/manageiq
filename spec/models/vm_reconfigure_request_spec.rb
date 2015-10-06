require "spec_helper"

describe VmReconfigureRequest do
  let(:admin) { FactoryGirl.create(:user, :userid => "tester") }
  before do
    _guid1, _server, @zone1 = EvmSpecHelper.create_guid_miq_server_zone
    @request = FactoryGirl.create(:vm_reconfigure_request, :userid => admin.userid)

    zone2  = FactoryGirl.create(:zone, :name => "zone_2")
    FactoryGirl.create(:miq_server, :zone => zone2)
    @vm = FactoryGirl.create(:vm_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware, :zone => zone2))
  end

  it("#my_role should be 'ems_operations'") { expect(@request.my_role).to eq('ems_operations') }

  describe '#my_zone' do
    context 'with valid sources' do
      before { @request.update_attributes(:options => {:src_ids => [@vm.id]}) }

      it "shoud be the same as VM's zone" do
        expect(@request.my_zone).to eq(@vm.my_zone)
      end

      it "should not be the same as the request's zone" do
        expect(@request.my_zone).not_to eq(@zone1.name)
      end
    end

    context "with no source" do
      it "should be the same as the request's zone" do
        @request.update_attributes(:options => {})
        expect(@request.my_zone).to eq(@zone1.name)
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

  context ".request_limits" do
    subject { described_class.request_limits(@options) }

    context "RHEV only" do
      before do
        @vm   = FactoryGirl.create(:vm_redhat)
        @options = {:src_ids => [@vm.id]}
      end

      it "single vm" do
        expect(subject[:min__number_of_sockets]).to eq(1)
        expect(subject[:max__number_of_sockets]).to eq(16)
        expect(subject[:min__total_vcpus]).to eq(1)
        expect(subject[:max__total_vcpus]).to eq(160)
        expect(subject[:min__vm_memory]).to      eq(4)
        expect(subject[:max__vm_memory]).to      eq(2.terabyte / 1.megabyte)
      end

      it "multiple vms" do
        vm2   = FactoryGirl.create(:vm_redhat)
        @options[:src_ids] << vm2.id

        expect(subject[:min__number_of_sockets]).to eq(1)
        expect(subject[:max__number_of_sockets]).to eq(16)
        expect(subject[:min__total_vcpus]).to eq(1)
        expect(subject[:max__total_vcpus]).to eq(160)
        expect(subject[:min__vm_memory]).to      eq(4)
        expect(subject[:max__vm_memory]).to      eq(2.terabyte / 1.megabyte)
      end
    end

    context "Vmware only" do
      before do
        @host = FactoryGirl.create(:host,
                                   :hardware => FactoryGirl.create(:hardware,
                                                                   :logical_cpus     => 40,
                                                                   :numvcpus         => 10,
                                                                   :cores_per_socket => 4,
                                                                  )
                                  )
        @vm   = FactoryGirl.create(:vm_vmware, :host => @host, :hardware => FactoryGirl.create(:hardware, :virtual_hw_version => "07"))
        @options = {:src_ids => [@vm.id]}
      end

      it "single vm" do
        expect(subject[:min__number_of_sockets]).to eq(1)
        expect(subject[:max__number_of_sockets]).to eq(8)
        expect(subject[:min__total_vcpus]).to eq(1)
        expect(subject[:max__total_vcpus]).to eq(8)
        expect(subject[:min__vm_memory]).to      eq(4)
        expect(subject[:max__vm_memory]).to      eq(255.gigabyte / 1.megabyte)
      end

      it "multiple vms" do
        host2 = FactoryGirl.create(:host,
                                   :hardware => FactoryGirl.create(:hardware,
                                                                   :logical_cpus     => 30,
                                                                   :numvcpus         => 15,
                                                                   :cores_per_socket => 2,
                                                                  )
                                  )
        vm2   = FactoryGirl.create(:vm_vmware, :host => host2, :hardware => FactoryGirl.create(:hardware, :virtual_hw_version => "07"))
        @options[:src_ids] << vm2.id

        expect(subject[:min__number_of_sockets]).to eq(1)
        expect(subject[:max__number_of_sockets]).to eq(8)
        expect(subject[:min__total_vcpus]).to eq(1)
        expect(subject[:max__total_vcpus]).to eq(8)
        expect(subject[:min__vm_memory]).to      eq(4)
        expect(subject[:max__vm_memory]).to      eq(255.gigabyte / 1.megabyte)
      end
    end

    it "hybrid" do
      vm1  = FactoryGirl.create(:vm_redhat)
      host = FactoryGirl.create(:host,
                                :hardware => FactoryGirl.create(:hardware,
                                                                :logical_cpus     => 30,
                                                                :numvcpus         => 15,
                                                                :cores_per_socket => 2,
                                                               )
                               )
      vm2  = FactoryGirl.create(:vm_vmware, :host => host, :hardware => FactoryGirl.create(:hardware, :virtual_hw_version => "07"))
      @options = {:src_ids => [vm1.id, vm2.id]}

      expect(subject[:min__number_of_sockets]).to eq(1)
      expect(subject[:max__number_of_sockets]).to eq(8)
      expect(subject[:min__total_vcpus]).to eq(1)
      expect(subject[:max__total_vcpus]).to eq(8)
      expect(subject[:min__vm_memory]).to      eq(4)
      expect(subject[:max__vm_memory]).to      eq(255.gigabyte / 1.megabyte)
    end
  end
end
