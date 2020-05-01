RSpec.describe VmMigrateRequest do
  let(:admin)         { FactoryBot.create(:user) }
  let(:request)       { FactoryBot.create(:vm_cloud_reconfigure_request, :requester => admin, :options => {:src_ids => [vm_amazon.id]}) }
  let(:vm_amazon)     { FactoryBot.create(:vm_amazon, :ext_management_system => FactoryBot.create(:ems_amazon)) }

  before { _guid, _server, @zone1 = EvmSpecHelper.create_guid_miq_server_zone }

  it("#my_role should be 'ems_operations'") { expect(request.my_role).to eq('ems_operations') }
  it("#vm is present") { expect(request.vm).to eq(vm_amazon) }

  context '#my_zone' do
    it "with valid source should have the VM's zone, not the request's zone" do
      expect(request.my_zone).to     eq(vm_amazon.my_zone)
      expect(request.my_zone).not_to eq(@zone1.name)
      expect(vm_amazon.my_zone).not_to eq(@zone1)
    end

    it "with no source should be the same as the request's zone" do
      request.update(:options => {:src_ids => []})

      expect(request.my_zone).to eq(@zone1.name)
    end
  end

  context "#my_queue_name" do
    it "with valid source should have the VM's queue_name_for_ems_operations" do
      expect(request.my_queue_name).to eq(vm_amazon.queue_name_for_ems_operations)
    end

    it "with no source should be nil" do
      request.update(:options => {:src_ids => []})

      expect(request.my_queue_name).to be_nil
    end
  end
end
