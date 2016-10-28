describe ManageIQ::Providers::Vmware::InfraManager::Vm::Reconfigure do
  let(:vm) do
    FactoryGirl.create(
      :vm_vmware,
      :name            => 'test_vm',
      :raw_power_state => 'poweredOff',
      :storage         => FactoryGirl.create(:storage, :name => 'storage'),
      :hardware        => FactoryGirl.create(:hardware, :virtual_hw_version => "07")
    )
  end

  it "#reconfigurable?" do
    expect(vm.reconfigurable?).to be_truthy
  end

  context "#max_total_vcpus" do
    before do
      @host = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 160))
      vm.host = @host
    end
    subject { vm.max_total_vcpus }

    context "vitural_hw_version" do
      it "07" do
        expect(subject).to eq(8)
      end

      it "08" do
        vm.hardware.update_attributes(:virtual_hw_version => "08")
        expect(subject).to eq(32)
      end

      it "09" do
        vm.hardware.update_attributes(:virtual_hw_version => "09")
        expect(subject).to eq(64)
      end

      it "10" do
        vm.hardware.update_attributes(:virtual_hw_version => "10")
        expect(subject).to eq(64)
      end

      it "11" do
        vm.hardware.update_attributes(:virtual_hw_version => "11")
        expect(subject).to eq(128)
      end
    end

    it "small host logical cpus" do
      @host.hardware.update_attributes(:cpu_total_cores => 4)
      expect(subject).to eq(4)
    end

    it "big host logical cpus" do
      expect(subject).to eq(8)
    end

    it 'when no host' do
      vm.update_attributes(:host_id => nil)
      expect(subject).to eq(vm.max_total_vcpus_by_version)
    end
  end

  context "#build_config_spec" do
    let(:options ) { {:vm_memory => '1024', :number_of_cpus => '8', :cores_per_socket => '2'} }
    subject { vm.build_config_spec(options) }

    it "memoryMB" do
      expect(subject["memoryMB"]).to eq(1024)
    end

    it "numCPUs" do
      expect(subject["numCPUs"]).to eq(8)
    end

    context "numCoresPerSocket" do
      it "vm_vmware virtual_hw_version = 07" do
        expect(subject["extraConfig"]).to eq([{"key" => "cpuid.coresPerSocket", "value" => "2"}])
      end

      it "vm_vmware virtual_hw_version != 07" do
        vm.hardware.update_attributes(:virtual_hw_version => "08")
        expect(subject["numCoresPerSocket"]).to eq(2)
      end
    end
  end

  context "#add_disk_config_spec" do
    before do
      @vmcs    = VimHash.new("VirtualMachineConfigSpec")
      @options = {:disk_size_in_mb => 10, :controller_key => 1000, :unit_number => 2}
    end
    subject { vm.add_disk_config_spec(@vmcs, @options).first }

    it 'required option' do
      @options.delete(:disk_size_in_mb)
      expect { subject }.to raise_error(RuntimeError, /Disk size is required to add a new disk./)
    end

    it 'with default options' do
      expect(subject["operation"]).to                          eq("add")
      expect(subject["fileOperation"]).to                      eq("create")
      expect(subject.fetch_path("device", "controllerKey")).to eq(1000)
      expect(subject.fetch_path("device", "unitNumber")).to    eq(2)
      expect(subject.fetch_path("device", "capacityInKB")).to  eq(10 * 1024)
      expect(subject.fetch_path("device", "backing", "thinProvisioned")).to be_truthy
      expect(subject.fetch_path("device", "backing", "diskMode")).to        eq("persistent")
      expect(subject.fetch_path("device", "backing", "fileName")).to        eq("[#{vm.storage.name}]")
    end

    it 'with user inputs' do
      @options[:thin_provisioned] = false
      @options[:dependent]        = false
      @options[:persistent]       = false
      @options[:disk_name]        = 'test_disk'

      expect(subject.fetch_path("device", "backing", "thinProvisioned")).to be_falsey
      expect(subject.fetch_path("device", "backing", "diskMode")).to        eq("independent_nonpersistent")
      expect(subject.fetch_path("device", "backing", "fileName")).to        eq("[#{vm.storage.name}]")
    end
  end

  context '#remove_disk_config_spec' do
    before do
      @vmcs     = VimHash.new("VirtualMachineConfigSpec")
      @vim_obj  = double('provider object', :getDeviceKeysByBacking => [900, 1])
      @filename = "[datastore] vm_name/abc.vmdk"
      @options  = {:disk_name => @filename}
    end
    subject { vm.remove_disk_config_spec(@vim_obj, @vmcs, @options).first }

    it 'with default options' do
      expect(subject["operation"]).to eq("remove")
      device = subject["device"]
      expect(device["controllerKey"]).to  eq(900)
      expect(device["capacityInKB"]).to   eq(0)
      expect(device["key"]).to            eq(1)
    end

    it 'keep backfile' do
      expect(subject["fileOperation"]).to be_nil
    end

    it 'delete backfile' do
      @options[:delete_backing] = true
      expect(subject["fileOperation"]).to eq("destroy")
    end
  end

  context '#backing_filename' do
    subject { vm.backing_filename }

    it 'no primary disk' do
      expect(subject).to eq("[#{vm.storage.name}]")
    end

    it 'with primary disk' do
      datastore = FactoryGirl.create(:storage, :name => "test_datastore")
      FactoryGirl.create(
        :disk,
        :device_type => "disk",
        :storage     => datastore,
        :hardware_id => vm.hardware.id
      )
      expect(subject).to eq("[#{datastore.name}]")
    end
  end

  context '#disk_mode' do
    subject { vm.disk_mode(@dependent, @persistent) }

    it 'persistent' do
      @dependent, @persistent = [true, true]
      expect(subject).to eq('persistent')
    end

    it 'nonpersistent' do
      @dependent, @persistent = [true, false]
      expect(subject).to eq('nonpersistent')
    end

    it 'independent_persistent' do
      @dependent, @persistent = [false, true]
      expect(subject).to eq('independent_persistent')
    end

    it 'independent_nonpersistent' do
      @dependent, @persistent = [false, false]
      expect(subject).to eq('independent_nonpersistent')
    end
  end

  context '#add_disks' do
    let(:vim)  { double("vim object") }
    let(:vmcs) { double("VirtualMachineConfigSpec").as_null_object }

    context 'add 1 disk' do
      let(:disk) { {:disk_size_in_mb => 1024} }

      it 'with valid controller key' do
        allow(vim).to receive(:available_scsi_units).and_return([[1000, 1]])
        allow(vim).to receive(:available_scsi_buses).and_return([1, 2, 3])

        expect(vm).not_to receive(:add_scsi_controller)
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, disk).once
        vm.add_disks(vim, vmcs, [disk])
      end

      it 'with no controller key' do
        allow(vim).to receive(:available_scsi_units).and_return([])
        allow(vim).to receive(:available_scsi_buses).and_return([1, 2, 3])

        expect(vm).to receive(:add_scsi_controller).with(vmcs, 1, -99).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, disk).once
        vm.add_disks(vim, vmcs, [disk])
      end
    end

    context 'add 2 disks' do
      let(:disks) { [{:disk_size_in_mb => 1024}, {:disk_size_in_mb => 2048}] }

      it 'with 2 free controller units' do
        allow(vim).to receive(:available_scsi_units).and_return([[1000, 14], [1000, 15]])
        allow(vim).to receive(:available_scsi_buses).and_return([1, 2, 3])

        expected_disks = [
          disks[0].merge(:controller_key => 1000, :unit_number => 14),
          disks[1].merge(:controller_key => 1000, :unit_number => 15)
        ]

        expect(vm).not_to receive(:add_scsi_controllers)
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[0]).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[1]).once

        vm.add_disks(vim, vmcs, disks)
      end

      it 'with 2 non-consecutive controller units' do
        allow(vim).to receive(:available_scsi_units).and_return([[1000, 1], [1000, 3]])
        allow(vim).to receive(:available_scsi_buses).and_return([1, 2, 3])

        expected_disks = [
          disks[0].merge(:controller_key => 1000, :unit_number => 1),
          disks[1].merge(:controller_key => 1000, :unit_number => 3)
        ]

        expect(vm).not_to receive(:add_scsi_controllers)
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[0]).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[1]).once

        vm.add_disks(vim, vmcs, disks)
      end

      it 'with 1 free controller unit' do
        allow(vim).to receive(:available_scsi_units).and_return([[1000, 15]])
        allow(vim).to receive(:available_scsi_buses).and_return([1, 2, 3])

        expected_disks = [
          disks[0].merge(:controller_key => 1000, :unit_number => 15),
          disks[1].merge(:controller_key => -99,  :unit_number => 0)
        ]

        expect(vm).to receive(:add_scsi_controller).with(vmcs, 1, -99).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[0]).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[1]).once

        vm.add_disks(vim, vmcs, disks)
      end

      it 'with 1 free unit on second controller' do
        allow(vim).to receive(:available_scsi_units).and_return([[1001, 15]])
        allow(vim).to receive(:available_scsi_buses).and_return([2, 3])

        expected_disks = [
          disks[0].merge(:controller_key => 1001, :unit_number => 15),
          disks[1].merge(:controller_key => -99,  :unit_number => 0)
        ]

        expect(vm).to receive(:add_scsi_controller).with(vmcs, 2, -99).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[0]).once
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disks[1]).once

        vm.add_disks(vim, vmcs, disks)
      end

      it 'with 1 free unit on the last scsi controller' do
        allow(vim).to receive(:available_scsi_units).and_return([[1003, 15]])
        allow(vim).to receive(:available_scsi_buses).and_return([])

        expected_disk = disks[0].merge(:controller_key => 1003, :unit_number => 15)

        expect(vm).not_to receive(:add_scsi_controller)
        expect(vm).to receive(:add_disk_config_spec).with(vmcs, expected_disk).once

        vm.add_disks(vim, vmcs, disks)
      end
    end
  end
end
