describe MiqAeMethodService::MiqAeServiceEmsEvent do
  before(:each) do
    @ems           = FactoryGirl.create(:ems_vmware_with_authentication,
                                        :zone => FactoryGirl.create(:zone)
                                       )
    @vm            = FactoryGirl.create(:vm_vmware)
    @ems_event     = FactoryGirl.create(:ems_event,
                                        :vm_or_template        => @vm,
                                        :ext_management_system => @ems
                                       )
    @service_event = MiqAeMethodService::MiqAeServiceEmsEvent.find(@ems_event.id)
  end

  context "#refresh" do
    it "when queued" do
      expect(EmsRefresh).to receive(:queue_refresh).once.with([@ems], nil, false)
      @service_event.refresh("src_vm", false)
    end

    it "when with multiple targets" do
      @vm.update_attributes(:ext_management_system => @ems)
      expect(EmsRefresh).to receive(:queue_refresh).once do |*args|
        expect(args[0]).to match_array([@ems, @vm])
      end

      @service_event.refresh("src_vm", "dest_vm", false)
    end

    it "when target object is empty" do
      @ems_event.update_attributes(:ext_management_system => nil)
      @service_event.reload

      expect(EmsRefresh).not_to receive(:queue_refresh)
      @service_event.refresh("dest_vm", false)
    end

    it "when target is empty string" do
      expect(EmsRefresh).not_to receive(:queue_refresh)
      @service_event.refresh("", false)
    end

    it "when target is empty" do
      expect(EmsRefresh).not_to receive(:queue_refresh)
      @service_event.refresh([], false)
    end

    it "when target is nil" do
      expect(EmsRefresh).not_to receive(:queue_refresh)
      @service_event.refresh(nil, false)
    end

    it "when target is an array" do
      expect(EmsRefresh).to receive(:queue_refresh).once.with([@ems], nil, false)
      @service_event.refresh(%w(src_vm dest_vm), false)
    end
  end

  context "#policy" do
    before(:each) do
      @event = "vm_clone_start"
      @host  = FactoryGirl.create(:host)
      @vm.update_attributes(:host => @host)
    end

    it "when event raised" do
      expect(MiqEvent).to receive(:raise_evm_event).with(@vm, @event, anything)
      @service_event.policy("src_vm", @event, "host")
    end

    it "when target is nil" do
      expect(MiqEvent).not_to receive(:raise_evm_event)
      @service_event.policy(nil, @event, "host")
    end

    it "when target is blank" do
      expect(MiqEvent).not_to receive(:raise_evm_event)
      @service_event.policy("", @event, "host")
    end

    it "when ems event has no ems connected" do
      @ems_event.update_attributes(:ext_management_system => nil)
      @service_event.reload

      expect(MiqEvent).not_to receive(:raise_evm_event)
      @service_event.policy("src_vm", @event, "host")
    end

    it "when policy event is nil and ems event has event_type = nil" do
      expect(MiqEvent).not_to receive(:raise_evm_event)
      @service_event.policy("src_vm", nil, "host")
    end

    it "when policy event is nil, try ems event's event_type" do
      @ems_event.update_attributes(:event_type => "someEventType")
      @service_event.reload

      expect(MiqEvent).to receive(:raise_evm_event).with(@vm, "someEventType", anything)
      @service_event.policy("src_vm", nil, "host")
    end

    it "when target object is nil" do
      @ems_event.update_attributes(:vm_or_template => nil)
      @service_event.reload

      expect(MiqEvent).not_to receive(:raise_evm_event)
      @service_event.policy("src_vm", @event, "host")
    end

    it "when policy source object is nil" do
      @vm.update_attributes(:host => nil)

      expect(MiqEvent).not_to receive(:raise_evm_event)
      @service_event.policy("src_vm", @event, "host")
    end

    it "when uses default policy source" do
      expect(MiqEvent).to receive(:raise_evm_event) do |vm, event, inputs|
        expect(vm).to eq(@vm)
        expect(event).to eq(@event)
        expect(inputs).to have_key(:ext_management_systems)
        expect(inputs[:ext_management_systems]).to eq(@ems)
      end
      @service_event.policy("src_vm", @event, nil)
    end
  end

  context "#scan" do
    it "when target is found" do
      expect_any_instance_of(VmOrTemplate).to receive(:scan)
      @service_event.scan("src_vm")
    end

    it "when target is not found" do
      expect_any_instance_of(EmsEvent).to receive(:refresh).with("dest_vm", "dest_host")
      @service_event.scan("dest_vm", "dest_host")
    end
  end

  context "#src_vm_as_template" do
    it "when true" do
      @service_event.src_vm_as_template(true)
      expect(@ems_event.reload.vm_or_template.template).to eq(true)
    end

    it "when false" do
      @service_event.src_vm_as_template(false)
      expect(@ems_event.reload.vm_or_template.template).to eq(false)
    end

    it "when target object is nil" do
      @ems_event.update_attributes(:vm_or_template => nil)
      @service_event.reload

      expect_any_instance_of(EmsEvent).to receive(:refresh).with("src_vm")
      @service_event.src_vm_as_template(false)
    end
  end

  context "#change_event_target_state" do
    it "when target is valid" do
      @service_event.change_event_target_state("src_vm", "suspended")
      expect(@vm.reload.state).to eq("suspended")
    end

    it "when target object is nil" do
      @ems_event.update_attributes(:vm_or_template => nil)
      @service_event.reload

      expect_any_instance_of(EmsEvent).to receive(:refresh).with("src_vm")
      @service_event.change_event_target_state("src_vm", "suspended")
    end
  end

  it "#src_vm_disconnect_storage" do
    expect_any_instance_of(VmOrTemplate).to receive("disconnect_storage".to_sym).once
    @service_event.src_vm_disconnect_storage
  end
end
