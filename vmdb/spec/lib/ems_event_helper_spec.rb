require "spec_helper"

describe EmsEventHelper do
  context "fb12322 - MiqAeEvent.build_evm_event blows up expecting inputs[:policy] to be an instance of MiqPolicy, but it is a hash of { :vmdb_class => 'MiqPolicy', :vmdb_id => 42}" do
    before(:each) do
      [Zone, ExtManagementSystem, Host, Vm, Storage, EmsEvent, MiqEvent, MiqPolicy, MiqAction, MiqPolicyContent, MiqPolicySet].each { |klass| klass.delete_all }

      @zone      = FactoryGirl.create(:zone)
      @ems       = FactoryGirl.create(:ems_vmware,
                                  :zone                   => @zone,
                                  :name                   => 'vc7',
                                  :hostname               => 'vc7.manageiq.com',
                                  :ipaddress              => '10.10.10.2'
                                  )
      @storage   = FactoryGirl.create(:storage,
                                  :name                   => 'StarM1-Demo5',
                                  :store_type             => 'VMFS'
                                  )
      @host      = FactoryGirl.create(:host,
                                  :name                   => 'host7',
                                  :ext_management_system  => @ems,
                                  :vmm_vendor             => 'vmware',
                                  :vmm_version            => '4.0.0',
                                  :vmm_product            => 'ESX',
                                  :vmm_buildnumber        => 261974,
                                  :ipaddress              => '192.168.252.28',
                                  :hostname               => 'host7.manageiq.com'
                                  )
      @vm        = FactoryGirl.create(:vm_vmware,
                                  :ext_management_system  => @ems,
                                  :name                   => 'vm42',
                                  :location               => 'vm42/vm42.vmx',
                                  :storage                => @storage
                                  )

      @username = 'fred'
      @chain_id = 12345
      @ems_events = []
      @ems_events << FactoryGirl.create(:ems_event,
                                    :event_type             => 'PowerOnVM_Task',
                                    :message                => 'Task: Power On virtual machine',
                                    :host_name              => @host.ipaddress,
                                    :timestamp              => Time.now,
                                    :ext_management_system  => @ems,
                                    :host                   => @host,
                                    :vm                     => @vm,
                                    :vm_name                => @vm.name,
                                    :vm_location            => @vm.path,
                                    :source                 => 'VC',
                                    :chain_id               => @chain_id,
                                    :is_task                => false,
                                    :username               => @username
                                    )

      @ems_events << FactoryGirl.create(:ems_event,
                                    :event_type             => 'VmStartingEvent',
                                    :message                => "#{@vm.name} on host #{@host.ipaddress} in DC1 is starting",
                                    :host_name              => @host.ipaddress,
                                    :timestamp              => Time.now,
                                    :ext_management_system  => @ems,
                                    :host                   => @host,
                                    :vm                     => @vm,
                                    :vm_name                => @vm.name,
                                    :vm_location            => @vm.path,
                                    :source                 => 'VC',
                                    :chain_id               => @chain_id,
                                    :is_task                => false,
                                    :username               => @username
                                    )

      @ems_events << FactoryGirl.create(:ems_event,
                                    :event_type             => 'VmPoweredOnEvent',
                                    :message                => "#{@vm.name} on  #{@host.ipaddress} in DC1 is powered on",
                                    :host_name              => @host.ipaddress,
                                    :timestamp              => Time.now,
                                    :ext_management_system  => @ems,
                                    :host                   => @host,
                                    :vm                     => @vm,
                                    :vm_name                => @vm.name,
                                    :vm_location            => @vm.path,
                                    :source                 => 'VC',
                                    :chain_id               => @chain_id,
                                    :is_task                => false,
                                    :username               => @username
                                    )

      @ems_events << FactoryGirl.create(:ems_event,
                                    :event_type             => 'PowerOnVM_Task_Complete',
                                    :message                => 'PowerOnVM_Task Completed',
                                    :host_name              => @host.ipaddress,
                                    :timestamp              => Time.now,
                                    :ext_management_system  => @ems,
                                    :host                   => @host,
                                    :vm                     => @vm,
                                    :vm_name                => @vm.name,
                                    :vm_location            => @vm.path,
                                    :source                 => 'EVM',
                                    :chain_id               => 12345,
                                    :is_task                => false,
                                    :username               => @username
                                    )

      @miq_event_vm_start = FactoryGirl.create(:miq_event, :name => 'vm_start', :description => 'VM Power On')

      @policy_set = FactoryGirl.create(:miq_policy_set)
      @policy     = FactoryGirl.create(:miq_policy, :towhat => 'Vm', :active => true, :mode => 'control')
      automate_options = { :ae_message => 'create', :ae_hash => { "kevin" => "1", "q" => "1" } }
      @action     = FactoryGirl.create(:miq_action, :description => 'create_incident', :action_type => 'custom_automation', :options => automate_options)
      @policy_set.add_member(@policy)

      @policy_content  = FactoryGirl.create(:miq_policy_content,
                                        :miq_policy => @policy,
                                        :miq_action => @action,
                                        :miq_event => @miq_event_vm_start,
                                        :qualifier => 'success',
                                        :success_sequence => 1,
                                        :success_synchronous => true)

      @vm.add_policy(@policy)
    end

    it "should handle event properly" do
      routine = [ { "policy" => ["src_vm", "vm_start"] } ]
      h = EmsEventHelper.new(@ems_events.last)
      lambda { h.handle_routine(routine) }.should_not raise_error
    end

    it "should build evm event properly calling MiqAeEvent.build_evm_event" do
      inputs = { :ae_message => 'create', :ae_hash => { "kevin" => "1", "q" => "1" }, :vm => @vm }
      aevent = MiqAeEvent.build_evm_event("vm_start", inputs)

      aevent[:vm_id].should             == @vm.id
      aevent["VmOrTemplate::vm"].should == @vm.id
      aevent[:ae_hash]["kevin"].should  == "1"
      aevent[:ae_hash]["q"].should      == "1"
    end
  end
end
