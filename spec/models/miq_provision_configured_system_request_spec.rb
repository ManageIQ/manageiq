RSpec.describe MiqProvisionConfiguredSystemRequest do
  let(:admin)             { FactoryBot.create(:user) }
  let(:configured_system) { FactoryBot.create(:configured_system, :manager => FactoryBot.create(:ext_management_system), :hostname => "foo") }
  let(:request)           { FactoryBot.create(:miq_provision_configured_system_request, :requester => admin, :options => {:src_configured_system_ids => [configured_system.id]}) }
  let(:vm_amazon)         { FactoryBot.create(:vm_amazon) }

  before { _guid, _server, @zone1 = EvmSpecHelper.create_guid_miq_server_zone }

  it("#my_role should be 'ems_operations'") { expect(request.my_role).to eq('ems_operations') }
  it("#originating_controller should be 'configured_system'") { expect(request.originating_controller).to eq('configured_system') }
  it("#src_configured_systems from options hash src_ids") { expect(request.src_configured_systems.first).to eq(configured_system) }
  it("#requested_task_idx from options hash src_configured_system_ids") { expect(request.requested_task_idx.first).to eq(configured_system.id) }

  context ".request_task_class_from" do
    it "retrieves the provision task class" do
      expect(described_class.request_task_class_from('options' => {:src_vm_id => vm_amazon.id})).to eq ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionTask
    end
  end

  describe '.new_request_task' do
    it 'returns subclassed task' do
      expect(ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionTask).to receive(:new).with(:request_type =>'ATTRS')
      described_class.new_request_task(:request_type =>'ATTRS')
    end
  end

  context "#event_name" do
    it "configured_system_provision_request_mode" do
      expect(request.event_name("mode")).to eq("configured_system_provision_request_mode")
    end
  end

  context "#host_name" do
    it "single host" do
      expect(request.host_name).to eq("foo")
    end

    it "multiple hosts" do
      request.update(:options => {:src_configured_system_ids => [1, 2, 3]})

      expect(request.host_name).to eq("Multiple Hosts")
    end
  end

  context '#my_zone' do
    it "with valid source should have the VM's zone, not the requests zone" do
      expect(request.my_zone).to     eq(configured_system.my_zone)
      expect(request.my_zone).not_to eq(@zone1.name)
    end
  end

  context "#my_queue_name" do
    it "with valid source should have the system's queue_name_for_ems_operations" do
      expect(request.my_queue_name).to eq(configured_system.queue_name_for_ems_operations)
    end

    it "with no source should be nil" do
      request.update(:options => {:src_configured_system_ids => []})

      expect(request.my_queue_name).to be_nil
    end
  end
end
