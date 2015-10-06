require "spec_helper"

describe Service do
  it "#all_service_children" do
    service     = FactoryGirl.create(:service)
    service_c1  = FactoryGirl.create(:service, :service => service)
    service_c2  = FactoryGirl.create(:service, :service => service)
    service_c21 = FactoryGirl.create(:service, :service => service_c2)
    service_c22 = FactoryGirl.create(:service, :service => service_c2)

    service_c1.all_service_children.should match_array []
    service_c2.all_service_children.should match_array [service_c21, service_c22]
    service.all_service_children.should    match_array [service_c1, service_c2, service_c21, service_c22]
  end

  context "service events" do
    before(:each) do
      @service = FactoryGirl.create(:service)
    end

    it "raise_request_start_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_start)

      @service.raise_request_start_event
    end

    it "raise_started_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_started)

      @service.raise_started_event
    end

    it "raise_request_stop_event" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_stop)

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
  end

  context "VM associations" do
    before(:each) do
      @vm          = FactoryGirl.create(:vm_vmware)
      @vm_1        = FactoryGirl.create(:vm_vmware)

      @service     = FactoryGirl.create(:service)
      @service_c1  = FactoryGirl.create(:service, :service => @service)
      @service << @vm
      @service_c1 << @vm_1
      @service.save
      @service_c1.save
    end

    it "#direct_vms" do
      @service_c1.direct_vms.should match_array [@vm_1]
      @service.direct_vms.should    match_array [@vm]
    end

    it "#all_vms" do
      @service_c1.all_vms.should match_array [@vm_1]
      @service.all_vms.should    match_array [@vm, @vm_1]
    end

    it "#root_service" do
      @service.root_service.should == @service
      @service_c1.root_service.should == @service
    end

    it "#direct_service" do
      @vm.direct_service.should == @service
      @vm_1.direct_service.should == @service_c1
    end

    it "#service" do
      @vm.service.should == @service
      @vm_1.service.should == @service
    end
  end

  context "with a small env" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      MiqServer.stub(:my_server).and_return(@zone1.miq_servers.first)
      @service = FactoryGirl.create(:service, :name => 'Service 1')
    end

    it "should create a valid service" do
      @service.guid.should_not be_empty
      @service.service_resources.should have(0).things
    end

    it "should allow Vm resources to be added to the service" do
      @service << Vm.first
      @service.service_resources.should have(1).thing
    end

    it "should allow a resource to be connected only once" do
      ids = Vm.pluck(:id)
      vm_first = Vm.find(ids.first)
      @service << vm_first
      @service.service_resources.should have(1).thing

      @service.add_resource(vm_first)
      @service.service_resources.should have(1).thing

      @service.add_resource(Vm.find(ids.last))
      @service.service_resources.should have(2).things
    end

    it "should allow a service to connect to another service" do
      s2 = FactoryGirl.create(:service, :name => 'inner_service')
      @service << s2
      @service.service_resources.should have(1).thing
    end

    it "should not allow service to connect to itself" do
      expect { @service << @service }.to raise_error
    end

    it "should set the group index when adding a resource" do
      @service.last_group_index.should equal(0)
      @service.add_resource(Vm.first, :group_idx => 1)
      @service.last_group_index.should equal(1)
      @service.group_has_resources?(1).should be_true
      @service.group_has_resources?(0).should be_false
    end

    it "start" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_start)

      @service.start
    end

    it "stop" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@service, :request_service_stop)

      @service.stop
    end

    context "with VM resources" do
      before(:each) do
        Vm.all.each { |vm| @service.add_resource(vm) }
      end

      it "should iterate over each service resource" do
        each_count = 0
        @service.each_group_resource do |sr|
          each_count += 1
          sr.should be_kind_of(ServiceResource)
        end
        each_count.should equal(@service.service_resources.length)
      end

      it "should remove all connected resources" do
        @service.service_resources.should_not have(0).things
        @service.remove_all_resources
        @service.service_resources.should have(0).things
      end

      it "should check if a group index has resources" do
        @service.group_has_resources?(0).should be_true
        @service.group_has_resources?(1).should be_false
        @service.remove_all_resources
        @service.group_has_resources?(0).should be_false
        @service.group_has_resources?(1).should be_false
      end

      it "should return the last group index" do
        @service.last_group_index.should equal(0)
        @service.service_resources.first.group_idx = 1
        @service.last_group_index.should equal(1)
      end

      it "should return delay time for an action" do
        @service.delay_for_action(0, :start).should equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS)

        @service.service_resources.first.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS - 1
        @service.delay_for_action(0, :start).should equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS)

        @service.each_group_resource { |r| r.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS - 1 }
        @service.delay_for_action(0, :start).should equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS - 1)

        @service.service_resources.first.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1
        @service.delay_for_action(0, :start).should equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1)

        @service.each_group_resource { |r| r.start_delay = Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1 }
        @service.delay_for_action(0, :start).should equal(Service::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS + 1)

        @service.each_group_resource { |r| r.start_delay = 30 }
        @service.delay_for_action(0, :start).should equal(30)
      end

      it "should return the next group index" do
        @service.next_group_index(0).should be_nil

        @service.service_resources.first.group_idx = 1
        @service.next_group_index(0).should equal(1)
        @service.next_group_index(1).should be_nil

        @service.next_group_index(1, -1).should equal(0)
        @service.next_group_index(0, -1).should be_nil
      end

      it "should skip empty groups" do
        @service.service_resources.first.group_idx = 2
        @service.next_group_index(0).should equal(2)
        @service.next_group_index(1).should equal(2)
        @service.next_group_index(2).should be_nil

        @service.next_group_index(2, -1).should equal(0)
        @service.next_group_index(1, -1).should equal(0)
        @service.next_group_index(0, -1).should be_nil
      end

      it "should compact group indexes to remove empty groups" do
        @service.compact_group_indexes
        @service.last_group_index.should equal(0)

        @service.service_resources.first.group_idx = 3
        @service.last_group_index.should equal(3)
        @service.group_has_resources?(1).should be_false

        @service.compact_group_indexes
        @service.last_group_index.should equal(1)
        @service.group_has_resources?(1).should be_true

        @service.remove_all_resources
        @service.group_has_resources?(0).should be_false
        @service.compact_group_indexes
        @service.last_group_index.should equal(0)
      end

      it "should not allow the same VM to be added to more than one services" do
        vm = Vm.first
        @service.save
        vm.service.should_not be_nil
        service2 = FactoryGirl.create(:service)
        -> { service2.add_resource(vm) }.should raise_error(MiqException::Error)
        -> { service2 << vm            }.should raise_error(MiqException::Error)
      end

      it "#remove_resource" do
        @service.vms.length.should == 2
        @service.save

        sr = @service.remove_resource(Vm.first)
        sr.should be_kind_of(ServiceResource)

        @service.reload
        @service.vms.length.should == 1
      end
    end
  end
end
