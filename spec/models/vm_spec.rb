describe Vm do
  include_examples "OwnershipMixin"

  it "#corresponding_model" do
    expect(Vm.corresponding_model).to eq(MiqTemplate)
    expect(ManageIQ::Providers::Vmware::InfraManager::Vm.corresponding_model).to eq(ManageIQ::Providers::Vmware::InfraManager::Template)
    expect(ManageIQ::Providers::Redhat::InfraManager::Vm.corresponding_model).to eq(ManageIQ::Providers::Redhat::InfraManager::Template)
  end

  it "#corresponding_template_model" do
    expect(Vm.corresponding_template_model).to eq(MiqTemplate)
    expect(ManageIQ::Providers::Vmware::InfraManager::Vm.corresponding_template_model).to eq(ManageIQ::Providers::Vmware::InfraManager::Template)
    expect(ManageIQ::Providers::Redhat::InfraManager::Vm.corresponding_template_model).to eq(ManageIQ::Providers::Redhat::InfraManager::Template)
  end

  context "#template=" do
    before(:each) { @vm = FactoryGirl.create(:vm_vmware) }

    it "false" do
      @vm.update_attribute(:template, false)
      expect(@vm.type).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
      expect(@vm.template).to eq(false)
      expect(@vm.state).to eq("on")
      expect { @vm.reload }.not_to raise_error
      expect { ManageIQ::Providers::Vmware::InfraManager::Template.find(@vm.id) }.to raise_error ActiveRecord::RecordNotFound
    end

    it "true" do
      @vm.update_attribute(:template, true)
      expect(@vm.type).to eq("ManageIQ::Providers::Vmware::InfraManager::Template")
      expect(@vm.template).to eq(true)
      expect(@vm.state).to eq("never")
      expect { @vm.reload }.to raise_error ActiveRecord::RecordNotFound
      expect { ManageIQ::Providers::Vmware::InfraManager::Template.find(@vm.id) }.not_to raise_error
    end
  end

  it "#validate_remote_console_vmrc_support only suppored on vmware" do
    vm = FactoryGirl.create(:vm_redhat, :vendor => "redhat")
    expect { vm.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
  end

  context ".find_all_by_mac_address_and_hostname_and_ipaddress" do
    before do
      @hardware1 = FactoryGirl.create(:hardware)
      @vm1 = FactoryGirl.create(:vm_vmware, :hardware => @hardware1)

      @hardware2 = FactoryGirl.create(:hardware)
      @vm2 = FactoryGirl.create(:vm_vmware, :hardware => @hardware2)
    end

    it "mac_address" do
      address = "ABCDEFG"
      guest_device = FactoryGirl.create(:guest_device, :address => address, :device_type => "ethernet")
      @hardware1.guest_devices << guest_device

      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(address, nil, nil))
        .to eql([@vm1])
    end

    it "hostname" do
      hostname = "ABCDEFG"
      network = FactoryGirl.create(:network, :hostname => hostname)
      @hardware1.networks << network

      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(nil, hostname, nil))
        .to eql([@vm1])
    end

    it "ipaddress" do
      ipaddress = "127.0.0.1"
      network = FactoryGirl.create(:network, :ipaddress => ipaddress)
      @hardware1.networks << network

      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(nil, nil, ipaddress))
        .to eql([@vm1])
    end

    it "returns an empty list when all are blank" do
      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(nil, nil, nil)).to eq([])
      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress('', '', '')).to eq([])
    end
  end

  context "with relationships of multiple types" do
    before(:each) do
      @rp        = FactoryGirl.create(:resource_pool, :name => "RP")
      @parent_vm = FactoryGirl.create(:vm_vmware, :name => "Parent VM")
      @vm        = FactoryGirl.create(:vm_vmware, :name => "VM")
      @child_vm  = FactoryGirl.create(:vm_vmware, :name => "Child VM")

      @rp.with_relationship_type("ems_metadata")     { @rp.add_child(@vm) }
      @parent_vm.with_relationship_type("genealogy") { @parent_vm.add_child(@vm) }
      @vm.with_relationship_type("genealogy")        { @vm.add_child(@child_vm) }

      [@rp, @parent_vm, @vm, @child_vm].each(&:clear_relationships_cache)
    end

    context "#destroy" do
      before(:each) do
        @vm.destroy
      end

      it "should destroy all relationships" do
        expect(Relationship.where(:resource_type => "Vm", :resource_id => @vm.id).count).to eq(0)
        expect(Relationship.where(:resource_type => "Vm", :resource_id => @child_vm.id).count).to eq(0)

        expect(@parent_vm.children).to eq([])
        expect(@child_vm.parents).to eq([])
        expect(@rp.children).to eq([])
      end
    end
  end

  context "#invoke_tasks_local" do
    before(:each) do
      @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host)
      @vm = FactoryGirl.create(:vm_vmware, :host => @host)
    end

    it "sets up standard callback for non Power Operations" do
      options = {:task => "create_snapshot", :invoke_by => :task, :ids => [@vm.id]}
      Vm.invoke_tasks_local(options)
      expect(MiqTask.count).to eq(1)
      task = MiqTask.first
      expect(MiqQueue.count).to eq(1)
      msg = MiqQueue.first
      expect(msg.miq_callback).to eq({:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id, :args => ["Finished"]})
    end

    it "sets up powerops callback for Power Operations" do
      options = {:task => "start", :invoke_by => :task, :ids => [@vm.id]}
      Vm.invoke_tasks_local(options)
      expect(MiqTask.count).to eq(1)
      task = MiqTask.first
      expect(MiqQueue.count).to eq(1)
      msg = MiqQueue.first
      expect(msg.miq_callback).to eq({:class_name => @vm.class.base_class.name, :method_name => :powerops_callback, :instance_id => @vm.id, :args => [task.id]})

      allow(Vm).to receive(:start).and_raise(MiqException::MiqVimBrokerUnavailable)
      msg.deliver
    end

    it "retirement passes in userid" do
      options = {:task => "retire_now", :invoke_by => :task, :ids => [@vm.id], :userid => "Freddy"}
      Vm.invoke_tasks_local(options)
      expect(MiqTask.count).to eq(1)
      task = MiqTask.first
      expect(MiqQueue.count).to eq(1)
      msg = MiqQueue.first

      expect(msg.miq_callback).to eq({:class_name => "MiqTask", :method_name => :queue_callback,
                                  :instance_id => task.id, :args => ["Finished"]})
      expect(msg.args).to eq(["Freddy"])
    end
  end

  context "#start" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host_vmware)
      @vm = FactoryGirl.create(:vm_vmware,
                               :host      => @host,
                               :miq_group => FactoryGirl.create(:miq_group)
                              )
      FactoryGirl.create(:miq_event_definition, :name => :request_vm_start)
      # admin user is needed to process Events
      User.super_admin || FactoryGirl.create(:user_with_group, :userid => "admin")
    end

    it "policy passes" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:raw_start)

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.start
      status, message, result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, result)
    end

    it "policy prevented" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to_not receive(:raw_start)

      event = {:attributes => {"full_data" => {:policy => {:prevented => true}}}}
      allow_any_instance_of(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:get_obj_from_path).with("/").and_return(:event_stream => event)
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.start
      status, message, _result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
    end
  end

  context "#scan" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host_vmware)
      @vm = FactoryGirl.create(
        :vm_vmware,
        :host      => @host,
        :miq_group => FactoryGirl.create(:miq_group)
      )
      FactoryGirl.create(:miq_event_definition, :name => :request_vm_scan)
      # admin user is needed to process Events
      User.super_admin || FactoryGirl.create(:user_with_group, :userid => "admin")
    end

    it "policy passes" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:raw_scan)

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.scan
      status, message, result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, result)
    end

    it "policy prevented" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to_not receive(:raw_scan)

      event = {:attributes => {"full_data" => {:policy => {:prevented => true}}}}
      allow_any_instance_of(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:get_obj_from_path).with("/").and_return(:event_stream => event)
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.scan
      status, message, _result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
    end
  end

  it "#save_drift_state" do
    # TODO: Beef up with more data
    vm = FactoryGirl.create(:vm_vmware)
    vm.save_drift_state

    expect(vm.drift_states.size).to eq(1)
    expect(DriftState.count).to eq(1)

    expect(vm.drift_states.first.data).to eq({
      :class               => "ManageIQ::Providers::Vmware::InfraManager::Vm",
      :id                  => vm.id,
      :location            => vm.location,
      :name                => vm.name,
      :vendor              => "vmware",

      :files               => [],
      :filesystem_drivers  => [],
      :groups              => [],
      :guest_applications  => [],
      :kernel_drivers      => [],
      :linux_initprocesses => [],
      :patches             => [],
      :registry_items      => [],
      :tags                => [],
      :users               => [],
      :win32_services      => [],
    })
  end

  it '#set_remote_console_url' do
    vm = FactoryGirl.create(:vm_vmware)
    vm.send(:remote_console_url=, url = 'http://www.redhat.com', 1)

    console = SystemConsole.find_by(:vm_id => vm.id)
    expect(console.url).to eq(url)
    expect(console.url_secret).to be
  end
end
