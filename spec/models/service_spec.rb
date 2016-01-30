describe Service do
  it "#all_service_children" do
    service     = FactoryGirl.create(:service)
    service_c1  = FactoryGirl.create(:service, :service => service)
    service_c2  = FactoryGirl.create(:service, :service => service)
    service_c21 = FactoryGirl.create(:service, :service => service_c2)
    service_c22 = FactoryGirl.create(:service, :service => service_c2)

    expect(service_c1.all_service_children).to match_array []
    expect(service_c2.all_service_children).to match_array [service_c21, service_c22]
    expect(service.all_service_children).to    match_array [service_c1, service_c2, service_c21, service_c22]
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
      expect(@service_c1.direct_vms).to match_array [@vm_1]
      expect(@service.direct_vms).to    match_array [@vm]
    end

    it "#all_vms" do
      expect(@service_c1.all_vms).to match_array [@vm_1]
      expect(@service.all_vms).to    match_array [@vm, @vm_1]
    end

    it "#root_service" do
      expect(@service.root_service).to eq(@service)
      expect(@service_c1.root_service).to eq(@service)
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
    before(:each) do
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

      it "should compact group indexes to remove empty groups" do
        @service.compact_group_indexes
        expect(@service.last_group_index).to equal(0)

        @service.service_resources.first.group_idx = 3
        expect(@service.last_group_index).to equal(3)
        expect(@service.group_has_resources?(1)).to be_falsey

        @service.compact_group_indexes
        expect(@service.last_group_index).to equal(1)
        expect(@service.group_has_resources?(1)).to be_truthy

        @service.remove_all_resources
        expect(@service.group_has_resources?(0)).to be_falsey
        @service.compact_group_indexes
        expect(@service.last_group_index).to equal(0)
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
        expect(@service.vms.length).to eq(2)
        @service.save

        sr = @service.remove_resource(Vm.first)
        expect(sr).to be_kind_of(ServiceResource)

        @service.reload
        expect(@service.vms.length).to eq(1)
      end
    end
  end
end
