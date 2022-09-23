RSpec.describe VmCloudReconfigureRequest do
  let(:admin)         { FactoryBot.create(:user) }
  let(:host_hardware) { FactoryBot.build(:hardware, :cpu_total_cores => 40, :cpu_sockets => 10, :cpu_cores_per_socket => 4) }
  let(:host)          { FactoryBot.build(:host, :hardware => host_hardware) }
  let(:request)       { FactoryBot.create(:vm_cloud_reconfigure_request, :requester => admin, :options => {:src_ids => [vm_amazon.id]}) }
  let(:vm_hardware)   { FactoryBot.build(:hardware, :virtual_hw_version => "07") }
  let(:vm_amazon)     { FactoryBot.create(:vm_amazon, :hardware => vm_hardware, :host => host, :ext_management_system => FactoryBot.create(:ext_management_system)) }

  before { @zone1 = EvmSpecHelper.local_miq_server.zone }

  it("#my_role should be 'ems_operations'") { expect(request.my_role).to eq('ems_operations') }
  it("#vm is present") { expect(request.vm).to eq(vm_amazon) }

  context '#my_zone' do
    it "with valid source should have the VM's zone, not the requests zone" do
      expect(request.my_zone).to     eq(vm_amazon.my_zone)
      expect(request.my_zone).not_to eq(@zone1.name)
    end

    it "with no source should be the same as the request's zone" do
      request.update(:options => {:src_ids => nil})

      expect(request.my_zone).to eq(@zone1.name)
    end
  end

  context "#my_queue_name" do
    it "with valid source should have the VM's queue_name_for_ems_operations" do
      expect(request.my_queue_name).to eq(vm_amazon.queue_name_for_ems_operations)
    end

    it "with no source should be nil" do
      request.update(:options => {:src_ids => nil})

      expect(request.my_queue_name).to be_nil
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryBot.create(:user_with_group) }
    it "creates and update a request" do
      EvmSpecHelper.local_miq_server

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_cloud_reconfigure_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Cloud Reconfigure requested by <#{admin.userid}> for Vm:#{[vm_amazon.id].inspect}"
      )

      allow(MiqProvision).to receive(:get_next_vm_name).and_return("New VM")

      # the dialogs populate this
      values = {:src_ids => [vm_amazon.id]}

      request = described_class.make_request(nil, values, admin).first

      expect(request).to                be_valid
      expect(request).to                be_a_kind_of(described_class)
      expect(request.request_type).to   eq("vm_cloud_reconfigure")
      expect(request.description).to    eq("VM Cloud Reconfigure for: #{vm_amazon.name}")
      expect(request.requester).to      eq(admin)
      expect(request.userid).to         eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_cloud_reconfigure_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Cloud Reconfigure request updated by <#{alt_user.userid}> for Vm:#{[vm_amazon.id].inspect}"
      )
      described_class.make_request(request, values, alt_user)
    end

    it "splits into multiple requests if src_ids span regions" do
      other_region_id = ApplicationRecord.id_in_region(1, ApplicationRecord.my_region_number + 1)
      values = {:src_ids => [vm_amazon.id, other_region_id]}

      request_local = double(:local_region_request)
      request_remote = double(:remote_region_request)

      expect(MiqRequest).to receive(:make_request) do |_req, vals, _requester, _auto_approve|
        expect(vals).to eq(:src_ids => [vm_amazon.id], :request_type => :vm_cloud_reconfigure)
      end.and_return(request_local)

      expect(MiqRequest).to receive(:make_request) do |_req, vals, _requester, _auto_approve|
        expect(vals).to eq(:src_ids => [other_region_id], :request_type => :vm_cloud_reconfigure)
      end.and_return(request_remote)

      expect(described_class.make_request(nil, values, admin)).to match_array([request_local, request_remote])
    end
  end
end
