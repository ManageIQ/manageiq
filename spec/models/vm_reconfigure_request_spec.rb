RSpec.describe VmReconfigureRequest do
  let(:admin)         { FactoryBot.create(:user, :userid => "tester") }
  let(:ems_vmware)    { FactoryBot.create(:ems_vmware, :zone => zone2) }
  let(:host_hardware) { FactoryBot.build(:hardware, :cpu_total_cores => 40, :cpu_sockets => 10, :cpu_cores_per_socket => 4) }
  let(:host)          { FactoryBot.build(:host, :hardware => host_hardware) }
  let(:request)       { FactoryBot.create(:vm_reconfigure_request, :requester => admin) }
  let(:vm_hardware)   { FactoryBot.build(:hardware, :virtual_hw_version => "07") }
  let(:vm_redhat)     { FactoryBot.create(:vm_redhat) }
  let(:vm_vmware)     { FactoryBot.create(:vm_vmware, :hardware => vm_hardware, :host => host) }
  let(:zone2)         { FactoryBot.create(:zone, :name => "zone_2") }

  before { _guid, _server, @zone1 = EvmSpecHelper.create_guid_miq_server_zone }

  it("#my_role should be 'ems_operations'") { expect(request.my_role).to eq('ems_operations') }

  context '#my_zone' do
    it "with valid source should have the VM's zone, not the requests zone" do
      vm_vmware.update(:ems_id => ems_vmware.id)
      request.update(:options => {:src_ids => [vm_vmware.id]})

      expect(request.my_zone).to     eq(vm_vmware.my_zone)
      expect(request.my_zone).not_to eq(@zone1.name)
    end

    it "with no source should be the same as the request's zone" do
      expect(request.my_zone).to eq(@zone1.name)
    end
  end

  context "#my_queue_name" do
    it "with valid source should have the VM's queue_name_for_ems_operations" do
      vm_vmware.update(:ems_id => ems_vmware.id)
      request.update(:options => {:src_ids => [vm_vmware.id]})

      expect(request.my_queue_name).to eq(vm_vmware.queue_name_for_ems_operations)
    end

    it "with no source should be nil" do
      expect(request.my_queue_name).to be_nil
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryBot.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_reconfigure_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Reconfigure requested by <#{admin.userid}> for Vm:#{[vm_vmware.id].inspect}"
      )

      allow(MiqProvision).to receive(:get_next_vm_name).and_return("New VM")

      # the dialogs populate this
      values = {:src_ids => [vm_vmware.id]}

      request = described_class.make_request(nil, values, admin).first

      expect(request).to                be_valid
      expect(request).to                be_a_kind_of(described_class)
      expect(request.request_type).to   eq("vm_reconfigure")
      expect(request.description).to    eq("VM Reconfigure for: #{vm_vmware.name} - ")
      expect(request.requester).to      eq(admin)
      expect(request.userid).to         eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_reconfigure_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Reconfigure request updated by <#{alt_user.userid}> for Vm:#{[vm_vmware.id].inspect}"
      )
      described_class.make_request(request, values, alt_user)
    end

    it "splits into multiple requests if src_ids span regions" do
      other_region_id = ApplicationRecord.id_in_region(1, ApplicationRecord.my_region_number + 1)
      values = {:src_ids => [vm_vmware.id, other_region_id]}

      request_local = double(:local_region_request)
      request_remote = double(:remote_region_request)

      expect(MiqRequest).to receive(:make_request) do |_req, vals, _requester, _auto_approve|
        expect(vals).to eq(:src_ids => [vm_vmware.id], :request_type => :vm_reconfigure)
      end.and_return(request_local)

      expect(MiqRequest).to receive(:make_request) do |_req, vals, _requester, _auto_approve|
        expect(vals).to eq(:src_ids => [other_region_id], :request_type => :vm_reconfigure)
      end.and_return(request_remote)

      expect(described_class.make_request(nil, values, admin)).to match_array([request_local, request_remote])
    end
  end

  context ".request_limits" do
    subject { described_class.request_limits(@options) }

    context "RHEV only" do
      it "single vm" do
        @options = {:src_ids => [vm_redhat.id]}

        assert_rhev_cpu_and_memory_min_max
      end

      it "multiple vms" do
        @options = {:src_ids => [vm_redhat.id, FactoryBot.create(:vm_redhat).id]}

        assert_rhev_cpu_and_memory_min_max
      end
    end

    context "Vmware only" do
      it "single vm" do
        @options = {:src_ids => [vm_vmware.id]}

        assert_vmware_cpu_and_memory_min_max
      end

      it "multiple vms" do
        hardware = FactoryBot.build(:hardware, :virtual_hw_version => "07")
        @options = {:src_ids => [vm_vmware.id, FactoryBot.create(:vm_vmware, :host => host, :hardware => hardware).id]}

        assert_vmware_cpu_and_memory_min_max
      end
    end

    it "hybrid" do
      @options = {:src_ids => [vm_redhat.id, vm_vmware.id]}

      assert_vmware_cpu_and_memory_min_max
    end
  end

  def assert_rhev_cpu_and_memory_min_max
    expect(subject[:min__number_of_sockets]).to eq(1)
    expect(subject[:max__number_of_sockets]).to eq(16)
    expect(subject[:min__total_vcpus]).to       eq(1)
    expect(subject[:max__total_vcpus]).to       eq(160)
    expect(subject[:min__vm_memory]).to         eq(4)
    expect(subject[:max__vm_memory]).to         eq(2.terabyte / 1.megabyte)
  end

  def assert_vmware_cpu_and_memory_min_max
    expect(subject[:min__number_of_sockets]).to eq(1)
    expect(subject[:max__number_of_sockets]).to eq(8)
    expect(subject[:min__total_vcpus]).to       eq(1)
    expect(subject[:max__total_vcpus]).to       eq(8)
    expect(subject[:min__vm_memory]).to         eq(4)
    expect(subject[:max__vm_memory]).to         eq(255.gigabyte / 1.megabyte)
  end
end
