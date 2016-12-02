describe Service do
  include_examples "OwnershipMixin"

  context "service events" do
    before do
      @service = FactoryGirl.create(:service)
    end

    it "raise_request_start_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_start)
      expect(@service).to receive(:update_progress).with(:power_status=>"starting")

      @service.raise_request_start_event
    end

    it "raise_started_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_started)

      @service.raise_started_event
    end

    it "raise_request_stop_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_stop)
      expect(@service).to receive(:update_progress).with(:power_status=>"stopping")

      @service.raise_request_stop_event
    end

    it "raise_stopped_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_stopped)

      @service.raise_stopped_event
    end

    it "raise_provisioned_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_provisioned)

      @service.raise_provisioned_event
    end

    it "raise_final_process_event start" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_started)

      @service.raise_final_process_event('start')
    end

    it "raise_final_process_event stop" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_stopped)

      @service.raise_final_process_event('stop')
    end

    it "queues a power calculation if the next_group_index is nil" do
      expect(@service).to receive(:next_group_index).and_return(nil)
      expect(@service).to receive(:queue_power_calculation).never
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_started)

      @service.process_group_action(:start, 0, 1)
    end

    it "does not queue a power calculation if the next_group_index is not nil" do
      expect(@service).to receive(:next_group_index).and_return(1)
      expect(@service).to receive(:queue_power_calculation).never
      expect(@service).to receive(:queue_group_action).once
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_started).never

      @service.process_group_action(:start, 0, 1)
    end

    it "places a calculate_power_state job on the queue" do
      expect(MiqQueue).to receive(:put).once
      @service.queue_power_calculation(30, :start)
    end
  end

  context "VM associations" do
    before do
      @zone1 = FactoryGirl.create(:small_environment)
      allow(MiqServer).to receive(:my_server).and_return(@zone1.miq_servers.first)
      @vm          = FactoryGirl.create(:vm_vmware)
      @vm_1        = FactoryGirl.create(:vm_vmware)

      @service     = FactoryGirl.create(:service)
      @service_c1  = FactoryGirl.create(:service, :service => @service)
      @service << @vm
      @service_c1 << @vm_1
      @service.save
      @service_c1.save
    end

    it "#power_states" do
      expect(@service.power_states).to eq %w(on on)
    end

    it "#update_progress" do
      expect(@service.power_state).to be_nil
      @service.update_progress(:power_state => "on")
      expect(@service.power_state).to be_nil
      @service.update_progress(:power_state => "off")
      expect(@service.power_state).to be_nil
      @service.update_progress(:power_status => "stopping")
      expect(@service.power_status).to eq "stopping"
      expect { |b| @service.update_progress(:power_state => "timeout", &b) }.to yield_with_args(:reset => true)
      expect { |b| @service.update_progress(:increment => true, &b) }.to yield_with_args(:increment => 1)
    end

    it "#timed_out?" do
      @service.options[:delayed] = 3
      expect(@service.timed_out?).to be_truthy
      @service.options[:delayed] = 2
      expect(@service.timed_out?).to be_falsey
    end

    context "#calculate_power_state" do
      it "delays if power states don't match" do
        @service.calculate_power_state(:start)
        expect(@service.options[:delayed]).to eq 1
      end

      it "returns a power_state of 'on' and a power_status of 'start_complete' if power_states_match" do
        expect(@service).to receive(:power_states_match?).twice.and_return(true)
        @service.calculate_power_state(:start)
        expect(@service.power_state).to eq "on"
        expect(@service.power_status).to eq "start_complete"
      end
    end

    context "#power_states_match?" do
      it "returns the uniq value for the 'on' power state" do
        expect(@service).to receive(:map_power_states).with(:start).and_return(["on"])
        expect(@service.power_states_match?(:start)).to be_truthy
      end

      it "returns the uniq value for the 'off' power state" do
        expect(@service).to receive(:map_power_states).with(:stop).and_return(["off"])
        expect(@service).to receive(:power_states).and_return(["off"])
        expect(@service.power_states_match?(:stop)).to be_truthy
      end
    end

    context "#modify_power_state_delay" do
      it "sets delayed to nil on a reset request" do
        options = {:reset => true}
        @service.options[:delayed] = 3
        @service.save
        expect(@service.options[:delayed]).to eq 3
        @service.modify_power_state_delay(options)
        expect(@service.options[:delayed]).to be_nil
      end

      it "increments delayed by one when increment is passed in" do
        options = {:increment => 1}
        expect(@service.options[:delayed]).to be_nil
        @service.modify_power_state_delay(options)
        expect(@service.options[:delayed]).to eq 1
      end
    end

    it "#direct_vms" do
      expect(@service_c1.direct_vms).to match_array [@vm_1]
      expect(@service.direct_vms).to    match_array [@vm]
    end

    it "#all_vms" do
      expect(@service_c1.all_vms).to match_array [@vm_1]
      expect(@service.all_vms).to    match_array [@vm, @vm_1]
    end

    it "#direct_service" do
      expect(@vm.direct_service).to eq(@service)
      expect(@vm_1.direct_service).to eq(@service_c1)
    end

    it "#service" do
      expect(@vm.service).to eq(@service)
      expect(@vm_1.service).to eq(@service)
    end
  end

  context "with a small env" do
    before do
      @zone1 = FactoryGirl.create(:small_environment)
      allow(MiqServer).to receive(:my_server).and_return(@zone1.miq_servers.first)
      @service = FactoryGirl.create(:service, :name => 'Service 1')
    end

    it "should create a valid service" do
      expect(@service.guid).not_to be_empty
      expect(@service.service_resources.size).to eq(0)
    end

    it "should allow Vm resources to be added to the service" do
      @service << Vm.first
      expect(@service.service_resources.size).to eq(1)
    end

    it "should allow a resource to be connected only once" do
      ids = Vm.pluck(:id)
      vm_first = Vm.find(ids.first)
      @service << vm_first
      expect(@service.service_resources.size).to eq(1)

      @service.add_resource(vm_first)
      expect(@service.service_resources.size).to eq(1)

      @service.add_resource(Vm.find(ids.last))
      expect(@service.service_resources.size).to eq(2)
    end

    it "should allow a service to connect to another service" do
      s2 = FactoryGirl.create(:service, :name => 'inner_service')
      @service << s2
      expect(@service.service_resources.size).to eq(1)
    end

    it "should not allow service to connect to itself" do
      expect { @service << @service }.to raise_error(MiqException::MiqServiceCircularReferenceError)
    end

    it "should set the group index when adding a resource" do
      expect(@service.last_group_index).to equal(0)
      @service.add_resource(Vm.first, :group_idx => 1)
      expect(@service.last_group_index).to equal(1)
      expect(@service.group_has_resources?(1)).to be_truthy
      expect(@service.group_has_resources?(0)).to be_falsey
    end

    it "last_index" do
      @service.add_resource(Vm.first, :group_idx => 1, :start_delay => 60)
      expect(@service.last_index).to eq 1
    end

    it "start" do
      @service.add_resource(Vm.first, :group_idx => 0, :start_delay => 60)
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_start)
      expect(@service).to receive(:queue_group_action).with(:start, 0, 1, 60)

      @service.start
    end

    it "stop" do
      @service.add_resource(Vm.first, :group_idx => 1, :stop_delay => 60)
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_stop)
      expect(@service).to receive(:queue_group_action).with(:stop, 1, -1, 60)

      @service.stop
    end

    it "suspend" do
      @service.add_resource(Vm.first, :group_idx => 1, :stop_delay => 60)
      expect(@service).to receive(:update_progress).with(:power_status=>"suspending")
      expect(@service).to receive(:queue_group_action).with(:suspend, 1, -1, 60)

      @service.suspend
    end

    it "shutdown_guest" do
      @service.add_resource(Vm.first, :group_idx => 1, :stop_delay => 60)
      expect(@service).to receive(:queue_group_action).with(:shutdown_guest, 1, -1, 60)

      @service.shutdown_guest
    end

    context "with VM resources" do
      before do
        Vm.all.each { |vm| @service.add_resource(vm) }
      end

      it "should iterate over each service resource" do
        each_count = 0
        @service.each_group_resource do |sr|
          each_count += 1
          expect(sr).to be_kind_of(ServiceResource)
        end
        expect(each_count).to equal(@service.service_resources.length)
      end

      it "should remove all connected resources" do
        expect(@service.service_resources.size).not_to eq(0)
        @service.remove_all_resources
        expect(@service.service_resources.size).to eq(0)
      end

      it "should check if a group index has resources" do
        expect(@service.group_has_resources?(0)).to be_truthy
        expect(@service.group_has_resources?(1)).to be_falsey
        @service.remove_all_resources
        expect(@service.group_has_resources?(0)).to be_falsey
        expect(@service.group_has_resources?(1)).to be_falsey
      end

      it "should return the last group index" do
        expect(@service.last_group_index).to equal(0)
        @service.service_resources.first.group_idx = 1
        expect(@service.last_group_index).to equal(1)
      end

      it "should return delay time for an action" do
        expect(@service.delay_for_action(0, :start)).to equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS)

        @service.service_resources.first.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS - 1
        expect(@service.delay_for_action(0, :start)).to equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS)

        @service.each_group_resource { |r| r.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS - 1 }
        expect(@service.delay_for_action(0, :start)).to equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS - 1)

        @service.service_resources.first.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1
        expect(@service.delay_for_action(0, :start)).to equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1)

        @service.each_group_resource { |r| r.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1 }
        expect(@service.delay_for_action(0, :start)).to equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1)

        @service.each_group_resource { |r| r.start_delay = 30 }
        expect(@service.delay_for_action(0, :start)).to equal(30)
      end

      it "should return the next group index" do
        expect(@service.next_group_index(0)).to be_nil

        @service.service_resources.first.group_idx = 1
        expect(@service.next_group_index(0)).to equal(1)
        expect(@service.next_group_index(1)).to be_nil

        expect(@service.next_group_index(1, -1)).to equal(0)
        expect(@service.next_group_index(0, -1)).to be_nil
      end

      it "should skip empty groups" do
        @service.service_resources.first.group_idx = 2
        expect(@service.next_group_index(0)).to equal(2)
        expect(@service.next_group_index(1)).to equal(2)
        expect(@service.next_group_index(2)).to be_nil

        expect(@service.next_group_index(2, -1)).to equal(0)
        expect(@service.next_group_index(1, -1)).to equal(0)
        expect(@service.next_group_index(0, -1)).to be_nil
      end

      it "should not allow the same VM to be added to more than one services" do
        vm = Vm.first
        @service.save
        expect(vm.service).not_to be_nil
        service2 = FactoryGirl.create(:service)
        expect { service2.add_resource(vm) }.to raise_error(MiqException::Error)
        expect { service2 << vm            }.to raise_error(MiqException::Error)
      end

      it "#remove_resource" do
        @service.save
        expect(@service.vms.length).to eq(2)

        sr = @service.remove_resource(Vm.first)
        expect(sr).to be_kind_of(ServiceResource)

        @service.reload
        expect(@service.vms.length).to eq(1)
      end
    end
  end

  context "Chargeback report generation" do
    before do
      @vm = FactoryGirl.create(:vm_vmware)
      @vm_1 = FactoryGirl.create(:vm_vmware)
      @service = FactoryGirl.create(:service)
      @service.name = "Test_Service_1"
      @service << @vm
      @service.save
    end

    describe ".queue_chargeback_reports" do
      it "queue request to generate chargeback report for each service" do
        @service_c1 = FactoryGirl.create(:service, :service => @service)
        @service_c1.name = "Test_Service_2"
        @service_c1 << @vm_1
        @service_c1.save

        expect(MiqQueue).to receive(:put).twice
        described_class.queue_chargeback_reports
      end
    end

    describe "#chargeback_report_name" do
      it "creates chargeback report's name" do
        expect(@service.chargeback_report_name).to eq "Chargeback-Vm-Monthly-Test_Service_1"
      end
    end

    describe "#queue_chargeback_report_generation" do
      it "queue request to generate chargeback report" do
        expect(MiqQueue).to receive(:put) do |args|
          expect(args).to have_attributes(:class_name  => described_class.name,
                                          :method_name => "generate_chargeback_report",
                                          :args        => {:report_source => "Test Run"})
        end
        @service.queue_chargeback_report_generation(:report_source => "Test Run")
      end
    end

    describe "#generate_chargeback_report" do
      it "delete existing chargeback report result for service before generating new one" do
        FactoryGirl.create(:miq_chargeback_report_result, :name => @service.chargeback_report_name)
        expect(MiqReportResult.count).to eq 1

        report = double("MiqReport")
        allow(MiqReport).to receive(:new).and_return(report)
        expect(report).to receive(:queue_generate_table)

        @service.generate_chargeback_report
        expect(MiqReportResult.count).to eq 0
      end

      it "loads report template and initiate generation" do
        EvmSpecHelper.local_miq_server
        allow(Chargeback).to receive(:build_results_for_report_chargeback)
        @service.generate_chargeback_report
        expect(MiqReportResult.count).to eq 1
        expect(MiqReportResult.first.name).to eq @service.chargeback_report_name
      end
    end

    describe "#chargeback_yaml" do
      it "loads chargeback report template" do
        @user = FactoryGirl.create(:user_with_group)
        report_yaml = @service.chargeback_yaml

        report = MiqReport.new(report_yaml)
        allow(Chargeback).to receive(:build_results_for_report_chargeback)
        report.generate_table(:userid => @user.userid)
        cols_from_data = report.table.column_names.to_set
        cols_from_yaml = report_yaml['col_order'].to_set
        expect(cols_from_yaml).to be_subset(cols_from_data)
      end
    end

    describe "#chargeback_report" do
      it "returns chargeback report" do
        EvmSpecHelper.local_miq_server
        allow(Chargeback).to receive(:build_results_for_report_chargeback)
        @service.generate_chargeback_report
        expect(@service.chargeback_report).to have_key(:results)
      end
    end
  end

  describe "#children" do
    it "returns children" do
      create_deep_tree
      expect(@service.children).to match_array([@service_c1, @service_c2])
      expect(@service.services).to match_array([@service_c1, @service_c2]) # alias
      expect(@service.direct_service_children).to match_array([@service_c1, @service_c2]) # alias
    end
  end

  describe "#indirect_service_children" do
    it "returns 1 level down children" do
      create_deep_tree
      Vmdb::Deprecation.silenced do
        expect(@service.indirect_service_children).to match_array([@service_c11, @service_c12, @service_c121])
      end
    end
  end

  describe "#descendants" do
    it "returns all descendants" do
      create_deep_tree
      expect(@service.descendants).to match_array([@service_c1, @service_c11, @service_c12, @service_c121, @service_c2])
      expect(@service.all_service_children).to match_array([@service_c1, @service_c11, @service_c12, @service_c121,
                                                            @service_c2]) # alias
    end

    it "returns middle of tree descendants" do
      create_deep_tree
      expect(@service_c1.descendants).to match_array([@service_c11, @service_c12, @service_c121])
      expect(@service_c1.all_service_children).to match_array([@service_c11, @service_c12, @service_c121])
    end
  end

  describe "#subtree" do
    it "returns sub tree" do
      create_deep_tree
      expected_objects = [@service, @service_c1, @service_c11, @service_c12, @service_c121, @service_c2]
      expect(@service.subtree).to match_array(expected_objects)
    end

    it "returns sub tree of middle node" do
      create_deep_tree
      expected_objects = [@service_c1, @service_c11, @service_c12, @service_c121]
      expect(@service_c1.subtree).to match_array(expected_objects)
    end
  end

  describe "#ancestors" do
    it "returns middle of the tree ancestors" do
      create_deep_tree
      expected_objects = [@service_c12, @service_c1, @service]
      expect(@service_c121.ancestors).to match_array(expected_objects)
    end

    it "returns top level ancestors" do
      create_deep_tree
      expect(@service.ancestors).to be_empty
    end
  end

  describe "#parent_service" do
    it "returns no parent" do
      service = FactoryGirl.create(:service)
      expect(service.parent).to be_nil
    end

    it "returns parent" do
      service = FactoryGirl.create(:service)
      service_c1 = FactoryGirl.create(:service, :service => service)

      expect(service_c1.parent).to eq(service)
      expect(service_c1.parent_service).to eq(service) # alias
    end
  end

  describe "#has_parent" do
    it "has no parent" do
      service = FactoryGirl.create(:service)
      expect(service.has_parent).to be_falsey
      expect(service.has_parent?).to be_falsey # alias
    end

    it "has parent" do
      service = FactoryGirl.create(:service)
      service_c1 = FactoryGirl.create(:service, :service => service)

      expect(service_c1.has_parent).to be_truthy
      expect(service_c1.has_parent?).to be_truthy # alias
    end
  end

  describe "#root" do
    it "has root as self" do
      service = FactoryGirl.create(:service)
      expect(service.root).to eq(service)
      expect(service.root_service).to eq(service) # alias
    end

    it "has root as parent" do
      service = FactoryGirl.create(:service)
      service_c1 = FactoryGirl.create(:service, :service => service)
      expect(service_c1.root).to eq(service)
      expect(service_c1.root_service).to eq(service) # alias
    end
  end

  describe "#service_action" do
    let(:service) { FactoryGirl.create(:service) }
    let(:service_resource_nil) { double(:service_resource) }
    let(:service_resource_power) do
      instance_double("ServiceResource", :start_action => "Power On",
                                         :stop_action  => "Suspend")
    end
    let(:service_resource_power_off) { instance_double("ServiceResource", :stop_action => "Power Off") }
    let(:service_resource_shutdown) { instance_double("ServiceResource", :stop_action => "Shutdown") }
    let(:service_resource_nothing) do
      instance_double("ServiceResource", :start_action => "Do Nothing",
                                         :stop_action  => "Do Nothing")
    end

    context "service_resource start_action stop_action is nil" do
      it "returns the original action" do
        expect(service.service_action(:start, service_resource_nil)).to eq(:start)
        expect(service.service_action(:suspend, service_resource_nil)).to eq(:suspend)
        expect(service.service_action(:stop, service_resource_nil)).to eq(:stop)
        expect(service.service_action(nil, service_resource_nil)).to eq(nil)
      end
    end

    context "service_resource start_action stop_action is not nil" do
      it "returns :start for 'Power On'" do
        expect(service.service_action(:start, service_resource_power)).to eq(:start)
      end

      it "returns :stop for Power Off" do
        expect(service.service_action(:stop, service_resource_power_off)).to eq(:stop)
      end

      it "returns :shutdown_guest for Shutdown" do
        expect(service.service_action(:stop, service_resource_power_off)).to eq(:stop)
        expect(service.service_action(:stop, service_resource_shutdown)).to eq(:shutdown_guest)
      end

      it "returns nil for Do Nothing" do
        expect(service.service_action(:stop, service_resource_nothing)).to be_nil
        expect(service.service_action(:start, service_resource_nothing)).to be_nil
      end
    end
  end

  def create_deep_tree
    @service      = FactoryGirl.create(:service)
    @service_c1   = FactoryGirl.create(:service, :service => @service)
    @service_c11  = FactoryGirl.create(:service, :service => @service_c1)
    @service_c12  = FactoryGirl.create(:service, :service => @service_c1)
    @service_c121 = FactoryGirl.create(:service, :service => @service_c12)
    @service_c2   = FactoryGirl.create(:service, :service => @service)
  end
end
