describe MiqEmsRefreshCoreWorker::Runner do
  before(:each) do
    _guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => zone)

    # General stubbing for testing any worker (methods called during initialize)
    @worker_record = FactoryGirl.create(:miq_ems_refresh_core_worker, :queue_name => "ems_#{@ems.id}", :miq_server => server)
    allow_any_instance_of(described_class).to receive(:sync_config)
    allow_any_instance_of(described_class).to receive(:set_connection_pool_size)
    allow_any_instance_of(described_class).to receive(:heartbeat_using_drb?).and_return(false)
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:authentication_check).and_return([true, ""])

    @worker = MiqEmsRefreshCoreWorker::Runner.new(:guid => @worker_record.guid, :ems_id => @ems.id)
  end

  context "#process_update" do
    context "against a ManageIQ::Providers::Vmware::InfraManager::Vm" do
      before(:each) do
        Timecop.travel(1.day.ago) do
          @vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems, :raw_power_state => "unknown")
        end
      end

      it "with unknown properties" do
        should_not_have_changed @vm, "unknown.property" => "unknown_value"
      end

      context "with runtime.memoryOverhead HACK" do
        it "alone" do
          should_not_have_changed @vm, "runtime.memoryOverhead" => 123456
        end

        it "and other valid properties" do
          should_have_changed @vm, {"runtime.memoryOverhead" => 123456, "runtime.powerState" => "poweredOn"}, "on", false
        end
      end

      it "with a deleted Vm" do
        should_not_have_changed @vm, nil
      end

      it "with non-VM updates" do
        expect do
          @worker.process_update([VimString.new("host-123", "HostSystem", "ManagedObjectReference"), {"unknown.property" => "unknown_value"}])
        end.not_to raise_error
      end

      context "with runtime.powerState and/or config.template set to" do
        it "poweredOff, true" do
          should_have_changed @vm, {"runtime.powerState" => "poweredOff", "config.template" => "true"}, "never", true
        end

        it "poweredOff, false" do
          should_have_changed @vm, {"runtime.powerState" => "poweredOff", "config.template" => "false"}, "off", false
        end

        it "poweredOn, false" do
          should_have_changed @vm, {"runtime.powerState" => "poweredOn", "config.template" => "false"}, "on", false
        end

        it "poweredOn, unset" do
          should_have_changed @vm, {"runtime.powerState" => "poweredOn"}, "on", false
        end

        it "poweredOff, unset" do
          should_have_changed @vm, {"runtime.powerState" => "poweredOff"}, "off", false
        end

        it "suspended, unset" do
          should_have_changed @vm, {"runtime.powerState" => "suspended"}, "suspended", false
        end

        it "unset, true" do
          should_have_changed @vm, {"config.template" => "true"}, "never", true
        end

        it "unset, false" do
          should_not_have_changed @vm, "config.template" => "false"
        end
      end

      context "with guest.net" do
        it "and no networks persisted" do
          props = {"guest.net" => [{"ipAddress" => ["1.2.3.4", "::1:2:3:4"], 'macAddress' => "00:00:00:00:00:00"}]}
          @worker.process_update([@vm.ems_ref_obj, props])
          expect(@vm.ipaddresses).to be_empty
        end

        context "and networks already persisted" do
          before(:each) do
            @hw = FactoryGirl.create(:hardware, :vm_or_template => @vm)
            @nics = (1..2).collect { FactoryGirl.create(:guest_device_nic_with_network, :hardware => @hw) }.sort_by(&:address)
            @expected_addresses = @nics.collect { |n| [n.network.ipaddress, n.network.ipv6address] }
          end

          it "and no ip changes" do
            props = {"guest.net" => [{'macAddress' => @nics[0].address, 'connected' => true}]}
            @worker.process_update([@vm.ems_ref_obj, props])
            should_not_have_network_changes

            props = {}
            @worker.process_update([@vm.ems_ref_obj, props])
            should_not_have_network_changes
          end

          it "and ip changes but nic not connected" do
            props = {"guest.net" => [{"ipAddress" => ["1.2.3.4", "::1:2:3:4"], 'macAddress' => @nics[0].address, 'connected' => false}]}
            @worker.process_update([@vm.ems_ref_obj, props])
            should_not_have_network_changes
          end

          it "and ip changes for unknown nic" do
            props = {"guest.net" => [{"ipAddress" => ["1.2.3.4", "::1:2:3:4"], 'macAddress' => '00:00:00:00:00:00', 'connected' => false}]}
            @worker.process_update([@vm.ems_ref_obj, props])
            should_not_have_network_changes
          end

          it "and ip changes but nic doesn't have a network" do
            @nics[0].update_attribute(:network, nil)
            @expected_addresses[0] = [nil, nil]

            props = {"guest.net" => [{"ipAddress" => ["1.2.3.4", "::1:2:3:4"], 'macAddress' => @nics[0].address, 'connected' => true}]}
            @worker.process_update([@vm.ems_ref_obj, props])
            should_not_have_network_changes
          end

          it "and ip changes" do
            props = {"guest.net" => [{"ipAddress" => ["1.2.3.4", "::1:2:3:4"], 'macAddress' => @nics[0].address, 'connected' => true}]}
            @worker.process_update([@vm.ems_ref_obj, props])

            expected = [["1.2.3.4", "::1:2:3:4"], @expected_addresses[1]]
            should_have_network_changes(expected)
          end
        end

        def should_not_have_network_changes
          expect(@hw.nics.reload.sort_by(&:address).collect { |n| [n.network.try(:ipaddress), n.network.try(:ipv6address)] }).to eq(@expected_addresses)
        end

        def should_have_network_changes(expected)
          expect(@hw.nics.reload.sort_by(&:address).collect { |n| [n.network.try(:ipaddress), n.network.try(:ipv6address)] }).to eq(expected)
        end
      end
    end

    context "against a ManageIQ::Providers::Vmware::InfraManager::Template" do
      before(:each) do
        Timecop.travel(1.day.ago) do
          @template = FactoryGirl.create(:template_vmware_with_ref, :ext_management_system => @ems)
        end
      end

      context "with runtime.powerState and/or config.template set to" do
        it "poweredOff, false" do
          should_have_changed @template, {"runtime.powerState" => "poweredOff", "config.template" => "false"}, "off", false
        end

        it "poweredOn, false" do
          should_have_changed @template, {"runtime.powerState" => "poweredOn", "config.template" => "false"}, "on", false
        end

        it "poweredOff, true" do
          should_not_have_changed @template, "runtime.powerState" => "poweredOff"
        end

        it "poweredOff, set" do
          should_not_have_changed @template, "runtime.powerState" => "poweredOff"
        end

        it "unset, true" do
          should_not_have_changed @template, "config.template" => "true"
        end

        it "unset, false" do
          should_have_changed @template, {"config.template" => "false"}, "unknown", false
        end
      end
    end

    def should_have_changed(obj, props, expected_state, expected_template)
      expected_time = nil
      template_changes = (obj.template != expected_template)
      Timecop.freeze(Time.now) do
        @worker.process_update([obj.ems_ref_obj, props])
        expected_time = Time.now.utc
      end
      expect do
        if template_changes
          obj = obj.corresponding_model.find(obj.id)
        else
          obj.reload
        end
      end.not_to raise_error
      expect(obj.template).to eq(expected_template)
      expect(obj.state).to eq(expected_state)
      expect(obj.state_changed_on).to be_within(0.00001).of expected_time
    end

    def should_not_have_changed(obj, props)
      expected_template = obj.template
      expected_state    = obj.state
      expected_time     = obj.state_changed_on
      @worker.process_update([obj.ems_ref_obj, props])
      expect { obj.reload }.not_to raise_error
      expect(obj.template).to eq(expected_template)
      expect(obj.state).to eq(expected_state)
      expect(obj.state_changed_on).to be_within(0.00001).of expected_time
    end
  end
end
