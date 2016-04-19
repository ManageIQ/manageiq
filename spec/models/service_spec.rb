describe Service do
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

  describe "#children" do
    it "returns children" do
      create_deep_tree
      expect(@service.children).to match_array([@service_c1, @service_c2])
      expect(@service.services).to match_array([@service_c1, @service_c2]) # alias
      expect(@service.direct_service_children).to match_array([@service_c1, @service_c2]) # alias
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

  def create_deep_tree
    @service      = FactoryGirl.create(:service)
    @service_c1   = FactoryGirl.create(:service, :service => @service)
    @service_c11  = FactoryGirl.create(:service, :service => @service_c1)
    @service_c12  = FactoryGirl.create(:service, :service => @service_c1)
    @service_c121 = FactoryGirl.create(:service, :service => @service_c12)
    @service_c2   = FactoryGirl.create(:service, :service => @service)
  end
end
