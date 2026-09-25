RSpec.describe Vm do
  subject { FactoryBot.create(:vm) }

  include_examples "OwnershipMixin"
  include_examples "ComplianceMixin"

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
    before { @vm = FactoryBot.create(:vm_vmware) }

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
    vm = FactoryBot.create(:vm_redhat, :vendor => "redhat")
    expect { vm.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
  end

  it "#validate_native_console_support must be overridden" do
    vm = FactoryBot.create(:vm_vmware, :vendor => 'vmware')
    expect { vm.validate_native_console_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
  end

  context "with relationships of multiple types" do
    before do
      @rp        = FactoryBot.create(:resource_pool, :name => "RP")
      @parent_vm = FactoryBot.create(:vm_vmware, :name => "Parent VM")
      @vm        = FactoryBot.create(:vm_vmware, :name => "VM")
      @child_vm  = FactoryBot.create(:vm_vmware, :name => "Child VM")

      @rp.with_relationship_type("ems_metadata")     { @rp.add_child(@vm) }
      @parent_vm.with_relationship_type("genealogy") { @parent_vm.add_child(@vm) }
      @vm.with_relationship_type("genealogy")        { @vm.add_child(@child_vm) }

      [@rp, @parent_vm, @vm, @child_vm].each(&:clear_relationships_cache)
    end

    context "#destroy" do
      before do
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
    before do
      Zone.seed
      EvmSpecHelper.local_miq_server

      @host = FactoryBot.create(:host)
      @vm = FactoryBot.create(:vm_vmware, :host => @host)
    end

    it "sets up standard callback for non Power Operations" do
      options = {:task => "create_snapshot", :invoke_by => :task, :ids => [@vm.id]}
      Vm.invoke_tasks_local(options)
      expect(MiqTask.count).to eq(1)
      task = MiqTask.first
      expect(MiqQueue.count).to eq(1)
      msg = MiqQueue.first
      expect(msg.miq_callback).to eq({:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id, :args => ["Finished"]})
      expect(msg.miq_task_id).to eq(task.id)
    end

    it "sets up powerops callback for Power Operations" do
      options = {:task => "start", :invoke_by => :task, :ids => [@vm.id]}
      Vm.invoke_tasks_local(options)
      expect(MiqTask.count).to eq(1)
      task = MiqTask.first
      expect(MiqQueue.count).to eq(1)
      msg = MiqQueue.first
      expect(msg.miq_callback).to eq({:class_name => @vm.class.base_class.name, :method_name => :powerops_callback, :instance_id => @vm.id, :args => [task.id]})
      expect(msg.miq_task_id).to eq(task.id)

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
      EvmSpecHelper.local_miq_server
      @host = FactoryBot.create(:host_vmware)
      @vm = FactoryBot.create(:vm_vmware,
                               :host      => @host,
                               :miq_group => FactoryBot.create(:miq_group)
                              )
      FactoryBot.create(:miq_event_definition, :name => :request_vm_start)
      # admin user is needed to process Events
      User.super_admin || FactoryBot.create(:user_with_group, :userid => "admin")
    end

    it "policy passes" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:start_queue)

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.start
      MiqQueue.first.deliver_and_process
    end

    it "policy prevented" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to_not receive(:start_queue)

      event = {:attributes => {"full_data" => {:policy => {:prevented => true}}}}
      allow_any_instance_of(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:get_obj_from_path).with("/").and_return(:event_stream => event)
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.start
      status, message, _result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
    end
  end

  context "task tracking through check_policy_prevent" do
    let(:vm_class) { ManageIQ::Providers::Vmware::InfraManager::Vm }
    let(:raised_options) { [] }

    def prevented_workspace(message, prevented: true)
      event = double("event_stream", :attributes => {"full_data" => {:policy => {:prevented => prevented}}, "message" => message})
      MiqAeEngine::MiqAeWorkspaceRuntime.new.tap do |ws|
        allow(ws).to receive(:get_obj_from_path).with("/").and_return("event_stream" => event)
      end
    end

    def stub_policy_event
      allow(MiqEvent).to receive(:raise_evm_event) do |_target, _event, _inputs, options|
        raised_options << options
        double("event")
      end
    end

    def automate_callback
      cb = raised_options.last[:miq_callback]
      [cb[:args], cb]
    end

    def run_callback(vm, workspace)
      args, _cb = automate_callback
      vm.check_policy_prevent_task_callback(*args, "ok", "msg", workspace)
    end

    before do
      Zone.seed
      EvmSpecHelper.local_miq_server
      @host = FactoryBot.create(:host_vmware)
      @vm = FactoryBot.create(:vm_vmware, :host => @host, :miq_group => FactoryBot.create(:miq_group))
      FactoryBot.create(:miq_event_definition, :name => :request_vm_start)
      User.super_admin || FactoryBot.create(:user_with_group, :userid => "admin")
    end

    after { $_miq_worker_current_msg = nil }

    def queue_start
      Vm.invoke_tasks_local(:task => "start", :invoke_by => :task, :ids => [@vm.id], :userid => "admin")
      [MiqQueue.first, MiqTask.first]
    end

    it "keeps the task unfinished until the real work is done (power op)" do
      msg, task = queue_start
      expect(msg.class_name).to eq("VmOrTemplate")
      expect(msg.method_name).to eq("start")
      expect(msg.miq_task_id).to eq(task.id)
      expect(msg.miq_callback).to eq(:class_name => "VmOrTemplate", :instance_id => @vm.id, :method_name => :powerops_callback, :args => [task.id])
      stub_policy_event

      $_miq_worker_current_msg = msg
      msg.deliver_and_process

      expect(task.reload.state).not_to eq("Finished")
      args, cb = automate_callback
      expect(cb[:method_name]).to eq(:check_policy_prevent_task_callback)
      expect(args).to eq([task.id, :start_queue])

      $_miq_worker_current_msg = nil
      run_callback(@vm, prevented_workspace(nil, :prevented => false))

      raw = MiqQueue.find_by(:method_name => "raw_start")
      expect(raw.miq_task_id).to eq(task.id)
      expect(raw.miq_callback).to include(:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id)
      expect(task.reload.state).not_to eq("Finished")

      allow_any_instance_of(vm_class).to receive(:raw_start).and_return("started")
      raw.deliver_and_process
      task.reload
      expect(task.state).to eq("Finished")
      expect(task.status).to eq("Ok")
      expect(task.task_results).to eq("started")
    end

    it "does not persist a cleared callback when the message is retried" do
      msg, _task = queue_start
      original = msg.miq_callback
      stub_policy_event

      $_miq_worker_current_msg = msg
      msg.deliver

      expect(msg.changed).not_to include("miq_callback")
      msg.unget
      expect(MiqQueue.find(msg.id).miq_callback).to eq(original)
    end

    it "finishes the task with the policy message when prevented" do
      msg, task = queue_start
      stub_policy_event
      $_miq_worker_current_msg = msg
      msg.deliver_and_process
      $_miq_worker_current_msg = nil

      ws = prevented_workspace("Policy says no")
      expect_any_instance_of(vm_class).not_to receive(:start_queue)
      expect { run_callback(@vm, ws) }.not_to raise_error

      expect(ws).to have_received(:get_obj_from_path).with("/")
      task.reload
      expect([task.state, task.status, task.message]).to eq(["Finished", "Error", "Policy says no"])
      expect(MiqQueue.where(:method_name => "raw_start")).to be_empty
    end

    it "finishes the task with the policy message when prevented (via the queue callback)" do
      msg, task = queue_start
      stub_policy_event
      $_miq_worker_current_msg = msg
      msg.deliver_and_process
      $_miq_worker_current_msg = nil

      _args, cb = automate_callback
      row = MiqQueue.put(:class_name => @vm.class.name, :instance_id => @vm.id, :method_name => "id", :miq_callback => cb)
      ws = prevented_workspace("Policy says no")
      row.delivered("ok", "msg", ws)

      expect(ws).to have_received(:get_obj_from_path).with("/")
      task.reload
      expect([task.state, task.status, task.message]).to eq(["Finished", "Error", "Policy says no"])
      expect(MiqQueue.where(:method_name => "raw_start")).to be_empty
    end

    it "finishes the task when a synchronous action returns" do
      ems = FactoryBot.create(:ems_vmware)
      vm = FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => @host, :miq_group => FactoryBot.create(:miq_group))
      FactoryBot.create(:miq_event_definition, :name => :request_vm_shutdown_guest)
      expect(vm.has_active_ems?).to be(true)

      Vm.invoke_tasks_local(:task => "shutdown_guest", :invoke_by => :task, :ids => [vm.id], :userid => "admin")
      msg = MiqQueue.first
      task = MiqTask.first
      stub_policy_event
      $_miq_worker_current_msg = msg
      msg.deliver_and_process
      $_miq_worker_current_msg = nil

      expect(MiqEvent).to have_received(:raise_evm_event)
      expect(task.reload.state).not_to eq("Finished")

      expect_any_instance_of(vm_class).to receive(:raw_shutdown_guest).once
      run_callback(vm, prevented_workspace(nil, :prevented => false))

      task.reload
      expect([task.state, task.status]).to eq(%w[Finished Ok])
    end

    it "finishes the task when the queued raw message finishes (shape A)" do
      Vm.invoke_tasks_local(:task => "create_snapshot", :name => "snap", :description => "d", :memory => false, :invoke_by => :task, :ids => [@vm.id], :userid => "admin")
      msg = MiqQueue.first
      task = MiqTask.first
      FactoryBot.create(:miq_event_definition, :name => :request_vm_create_snapshot)
      stub_policy_event
      $_miq_worker_current_msg = msg
      msg.deliver_and_process
      $_miq_worker_current_msg = nil

      expect(task.reload.state).not_to eq("Finished")
      allow_any_instance_of(vm_class).to receive(:raw_create_snapshot)
      run_callback(@vm, prevented_workspace(nil, :prevented => false))

      raw = MiqQueue.find_by(:method_name => "raw_create_snapshot")
      expect(raw.miq_task_id).to eq(task.id)
      expect(raw.args).to eq(["snap", "d", false])
      expect(task.reload.state).not_to eq("Finished")

      expect_any_instance_of(vm_class).to receive(:raw_create_snapshot).once
      raw.deliver_and_process
      expect([task.reload.state, task.status]).to eq(%w[Finished Ok])
    end

    it "finishes the task with an error when the policy event is not queued (maintenance zone)" do
      msg, task = queue_start
      allow(Zone).to receive(:maintenance?).and_return(true)

      $_miq_worker_current_msg = msg
      msg.deliver_and_process

      expect(MiqQueue.where(:class_name => "MiqAeEngine")).to be_empty
      task.reload
      expect([task.state, task.status]).to eq(%w[Finished Error])
      expect(task.message).to include("not queued")
      expect(msg.miq_callback).to be_blank
    end

    it "agrees with MiqQueue.put on whether the policy event is queued" do
      allow_any_instance_of(MiqServer).to receive(:has_active_role?).and_call_original
      allow_any_instance_of(MiqServer).to receive(:has_active_role?).with("automate").and_return(true)
      zone = MiqServer.my_server.zone
      msg, = queue_start
      $_miq_worker_current_msg = msg

      expect(@vm.send(:policy_event_queueable?)).to be(true)
      MiqEvent.raise_evm_event(@vm, :request_vm_start, {}, {})
      expect(MiqQueue.where(:class_name => "MiqAeEngine").count).to eq(1)

      MiqQueue.where(:class_name => "MiqAeEngine").destroy_all
      MiqRegion.my_region.update!(:maintenance_zone => zone)
      expect(@vm.send(:policy_event_queueable?)).to be(false)
      MiqEvent.raise_evm_event(@vm, :request_vm_start, {}, {})
      expect(MiqQueue.where(:class_name => "MiqAeEngine").count).to eq(0)
    end

    it "queues the policy event in a maintenance zone when the automate role is not active (nil zone)" do
      allow_any_instance_of(MiqServer).to receive(:has_active_role?).and_call_original
      allow_any_instance_of(MiqServer).to receive(:has_active_role?).with("automate").and_return(false)
      MiqRegion.my_region.update!(:maintenance_zone => MiqServer.my_server.zone)
      msg, = queue_start
      $_miq_worker_current_msg = msg

      expect(@vm.send(:policy_event_queueable?)).to be(true)
      MiqEvent.raise_evm_event(@vm, :request_vm_start, {}, {})
      expect(MiqQueue.where(:class_name => "MiqAeEngine").count).to eq(1)
    end
  end

  context "#scan" do
    before do
      EvmSpecHelper.local_miq_server
      @host = FactoryBot.create(:host_vmware)
      @vm = FactoryBot.create(
        :vm_vmware,
        :host      => @host,
        :miq_group => FactoryBot.create(:miq_group)
      )
      FactoryBot.create(:miq_event_definition, :name => :request_vm_scan)
      # admin user is needed to process Events
      User.super_admin || FactoryBot.create(:user_with_group, :userid => "admin")
    end

    it "policy passes" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:raw_scan)

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.scan
      MiqQueue.first.deliver_and_process
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
    vm = FactoryBot.create(:vm_vmware)
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
    vm = FactoryBot.create(:vm_vmware)
    vm.send(:remote_console_url=, url = 'http://www.redhat.com', 1)

    console = SystemConsole.find_by(:vm_id => vm.id)
    expect(console.url).to eq(url)
    expect(console.url_secret).to be
  end

  describe '#add_to_service' do
    let(:vm) { FactoryBot.create(:vm_vmware) }
    let(:service) { FactoryBot.create(:service) }

    it 'associates the vm to the service' do
      vm.add_to_service(service)

      expect(service.reload.vms).to include(vm)
    end

    it 'raise an error if the vm is already part of a service' do
      vm.add_to_service(service)

      expect { vm.add_to_service(service) }.to raise_error MiqException::Error
    end
  end

  context "#supported_consoles" do
    it 'returns all of the console types' do
      vm = FactoryBot.create(:vm)
      expect(vm.supported_consoles.keys).to match_array([:html5, :vmrc, :native])
    end
  end

  context "#supports?(:vm_control_powered_on)" do
    it "returns true for powered on vms with control" do
      # need a vendor to properly specify the running state
      vm = FactoryBot.create(:vm_vmware,
                             :host                  => FactoryBot.create(:host),
                             :ext_management_system => FactoryBot.create(:ext_management_system))
      expect(vm.unsupported_reason(:control)).to eq(nil)
      expect(vm.unsupported_reason(:vm_control_powered_on)).to eq(nil)
    end

    it "returns the control reason if vm is not properly controlled" do
      vm = FactoryBot.create(:vm_vmware)
      expect(vm.unsupported_reason(:control)).to match(/not connected to a Host/i)
      expect(vm.unsupported_reason(:vm_control_powered_on)).to match(/not connected to a Host/i)
    end

    it "returns false for powered off vms with control" do
      vm = FactoryBot.create(:vm_vmware,
                             :raw_power_state       => "unknown",
                             :host                  => FactoryBot.create(:host),
                             :ext_management_system => FactoryBot.create(:ext_management_system))
      expect(vm.unsupported_reason(:vm_control_powered_on)).to match(/not powered on/i)
    end
  end
end
