require 'VMwareWebService/MiqVim'

describe MiqVimVm do
  context 'snapshot disk size check' do
    before(:each) do
      @inv_obj = double
      allow(@inv_obj).to receive(:sic).and_return(nil)
      allow(@inv_obj).to receive(:localVmPath).and_return('/test-vm/test-vm.vmx')

      vmh = {
        'summary' => {
          'config'  => {
            'name'       => VimString.new('test-vm'),
            'uuid'       => VimString.new('502fee93-3744-2d43-6a02-ddd0af96868c'),
            'vmPathName' => VimString.new('[local-dev] test-vm/test-vm.vmx')
          },
          'vm'      => VimString.new('vm-100'),
          'runtime' => {}
        }
      }
      @vim_vm = MiqVimVm.new(@inv_obj, vmh)
    end

    context "snapshot_directory_mor" do
      before(:each) do
        allow(@inv_obj).to receive(:path2dsName).and_return(VimString.new('path2dsName'))
        allow(@inv_obj).to receive(:dsName2mo_local).and_return(VimString.new('dsName2mo_local'))
      end

      context "API 4.x" do
        before(:each) do
          allow(@inv_obj).to receive(:apiVersion).and_return(VimString.new('4.1'))
        end

        it "snapshot_directory_mor" do
          expect(@vim_vm.snapshot_directory_mor({})).to eq('dsName2mo_local')
        end
      end

      context "API 5.x" do
        before(:each) do
          allow(@inv_obj).to receive(:apiVersion).and_return(VimString.new('5.0'))
          @redoNotWithParent = VimHash.new do |vh|
            vh.key =   'snapshot.redoNotWithParent'
            vh.value = 'false'
          end
          @config = {'config' => {'extraConfig' => [@redoNotWithParent]}}
        end

        it "without redoNotWithParent" do
          config = {'config' => {'extraConfig' => []}}
          expect(@vim_vm.snapshot_directory_mor(config)).to be_nil
        end

        it "API 5.x - with redoNotWithParent = false" do
          expect(@vim_vm.snapshot_directory_mor(@config)).to be_nil
        end

        it "API 5.x - with redoNotWithParent = true" do
          @redoNotWithParent['value'] = true
          expect(@vim_vm.snapshot_directory_mor(@config)).to eq('dsName2mo_local')
        end
      end
    end

    context "check_disk_space" do
      before(:each) do
        @ds_mor        = VimString.new('datastore-001')
        @ds_free_space = '1048576'   # 1 Megabyte
        ds_summary = {
          'summary' => {
            'name'      => 'test_datastore',
            'freeSpace' => @ds_free_space
          }
        }

        allow(@inv_obj).to receive(:getMoProp_local).and_return(ds_summary)
      end

      it "check_disk_space - 100 percent, small disk" do
        max_disk_space_in_kb = 1000
        @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 100)
      end

      it "check_disk_space - 100 percent, large disk" do
        max_disk_space_in_kb = 10000
        expect { @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 100) }.to raise_error(MiqException::MiqVmSnapshotError)
      end

      it "check_disk_space - 0 percent" do
        max_disk_space_in_kb = 10000
        expect { @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 0) }.not_to raise_error
      end

      it "check_disk_space - 10 percent" do
        max_disk_space_in_kb = 10000
        expect { @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 10) }.not_to raise_error
      end
    end

    context "disk_space_per_datastore" do
      before(:each) do
        @disk1 = VimHash.new('VirtualDisk') do |vh|
          vh.backing = {'diskMode' => 'persistent', 'datastore' => 'datastore-001'}
          vh.capacityInKB = 100
        end
        @disk2 = VimHash.new('VirtualDisk') do |vh|
          vh.backing = {'diskMode' => 'persistent', 'datastore' => 'datastore-002'}
          vh.capacityInKB = 200
        end

        @devices = [@disk1, @disk2]
      end

      it "multi-datastore" do
        result = @vim_vm.disk_space_per_datastore(@devices, nil)
        expect(result.size).to eq(2)
        expect(result['datastore-001']).to eq(100)
        expect(result['datastore-002']).to eq(200)
      end

      it "single-datastore" do
        @disk2.backing['datastore'] = 'datastore-001'
        result = @vim_vm.disk_space_per_datastore(@devices, nil)
        expect(result.size).to eq(1)
        expect(result['datastore-001']).to eq(300)
      end

      it "snapshot directory override" do
        result = @vim_vm.disk_space_per_datastore(@devices, 'datastore-snap')
        expect(result.size).to eq(1)
        expect(result['datastore-snap']).to eq(300)
      end
    end

    context "#available_scsi_units" do
      let(:miq_vim_vm) do
        {
          "config" => {
            "hardware" => {
              "device" => [
                VimHash.new("VirtualPCIController") do |pci|
                  pci["key"]       = "100"
                  pci["busNumber"] = "0"
                end
              ]
            }
          }
        }
      end

      before(:each) do
        allow(@inv_obj).to receive(:getMoProp).with("vm-100", "config.hardware").and_return(miq_vim_vm)
      end

      context "with 0 scsi controllers" do
        it "returns nil, nil" do
          controller_key, unit_number = @vim_vm.available_scsi_units.first
          expect(controller_key).to be_nil
          expect(unit_number).to    be_nil
        end
      end

      context "with 1 Bus Logic SATA controller" do
        before(:each) do
          pci_controller = miq_vim_vm["config"]["hardware"]["device"].detect { |dev| dev["key"] == "100" }
          pci_controller["device"] = []

          bus_logic_controller = VimHash.new("VirtualBusLogicController") do |scsi|
            scsi["key"]                = "1000"
            scsi["scsiCtlrUnitNumber"] = "7"
            scsi["controllerKey"]      = "100"
            scsi["unitNumber"]         = "0"
            scsi["busNumber"]          = "0"
          end

          miq_vim_vm["config"]["hardware"]["device"] << bus_logic_controller
          pci_controller["device"] << bus_logic_controller["key"]
        end

        context "with 0 disks" do
          it "returns the first unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(0)
          end
        end
      end

      context "with 1 Lsi Logic SATA controller" do
        before(:each) do
          pci_controller = miq_vim_vm["config"]["hardware"]["device"].detect { |dev| dev["key"] == "100" }
          pci_controller["device"] = []

          lsi_logic = VimHash.new("VirtualLsiLogicController") do |scsi|
            scsi["key"]                = "1000"
            scsi["scsiCtlrUnitNumber"] = "7"
            scsi["controllerKey"]      = "100"
            scsi["unitNumber"]         = "3"
            scsi["busNumber"]          = "0"
          end

          miq_vim_vm["config"]["hardware"]["device"] << lsi_logic
          pci_controller["device"] << lsi_logic["key"]
        end

        context "with 0 disks" do
          it "returns the first unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(0)
          end
        end
      end

      context "with 1 Lsi Logic SAS controller" do
        before(:each) do
          pci_controller = miq_vim_vm["config"]["hardware"]["device"].detect { |dev| dev["key"] == "100" }
          pci_controller["device"] = []

          lsi_logic_sas = VimHash.new("VirtualLsiLogicSASController") do |scsi|
            scsi["key"]                = "1000"
            scsi["scsiCtlrUnitNumber"] = "7"
            scsi["controllerKey"]      = "100"
            scsi["unitNumber"]         = "3"
            scsi["busNumber"]          = "0"
          end

          miq_vim_vm["config"]["hardware"]["device"] << lsi_logic_sas
          pci_controller["device"] << lsi_logic_sas["key"]
        end

        context "with 0 disks" do
          it "returns the first unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(0)
          end
        end
      end

      context "with 1 pvscsi controller" do
        before(:each) do
          pci_controller = miq_vim_vm["config"]["hardware"]["device"].detect { |dev| dev["key"] == "100" }
          pci_controller["device"] = []

          pvscsi = VimHash.new("ParaVirtualSCSIController") do |scsi|
            scsi["key"]                = "1000"
            scsi["deviceInfo"]         = {
              "label"   => "SCSI controller 0",
              "summary" => "VMware paravirtual SCSI"
            }
            scsi["scsiCtlrUnitNumber"] = "7"
            scsi["controllerKey"]      = "100"
            scsi["unitNumber"]         = "3"
            scsi["busNumber"]          = "0"
          end

          miq_vim_vm["config"]["hardware"]["device"] << pvscsi
          pci_controller["device"] << pvscsi["key"]
        end

        context "with 0 disks" do
          it "returns the first unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(0)
          end
        end

        context "with 1 disk" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            new_disk = VimHash.new("VirtualDisk") do |disk|
              disk["key"]           = "2000"
              disk["controllerKey"] = "1000"
              disk["unitNumber"]    = "0"
            end

            miq_vim_vm["config"]["hardware"]["device"] << new_disk
            scsi_controller["device"] << new_disk["key"]
          end

          it "returns the first available unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(1)
          end
        end

        context "with 2 consecutive disks" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            Array.new(2) do |i|
              new_disk = VimHash.new("VirtualDisk") do |disk|
                disk["key"]           = "200#{i}"
                disk["controllerKey"] = "1000"
                disk["unitNumber"]    = i.to_s
              end

              miq_vim_vm["config"]["hardware"]["device"] << new_disk
              scsi_controller["device"] << new_disk["key"]
            end
          end

          it "returns the first available unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(2)
          end
        end

        context "with 2 non-consecutive disks" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            [0, 2].each do |i|
              new_disk = VimHash.new("VirtualDisk") do |disk|
                disk["key"]           = "200#{i}"
                disk["controllerKey"] = "1000"
                disk["unitNumber"]    = i.to_s
              end

              miq_vim_vm["config"]["hardware"]["device"] << new_disk
              scsi_controller["device"] << new_disk["key"]
            end
          end

          it "returns the lowest available unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(1)
          end
        end

        context "with 7 consecutive disks" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            [*0..6].each do |i|
              new_disk = VimHash.new("VirtualDisk") do |disk|
                disk["key"]           = "200#{i}"
                disk["controllerKey"] = "1000"
                disk["unitNumber"]    = i.to_s
              end

              miq_vim_vm["config"]["hardware"]["device"] << new_disk
              scsi_controller["device"] << new_disk["key"]
            end
          end

          it "skips the scsi controller unit number" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(8)
          end
        end

        context "with a full scsi controller" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            [*0..6, *8..15].each do |i|
              new_disk = VimHash.new("VirtualDisk") do |disk|
                disk["key"]           = "200#{i}"
                disk["controllerKey"] = "1000"
                disk["unitNumber"]    = i.to_s
              end

              miq_vim_vm["config"]["hardware"]["device"] << new_disk
              scsi_controller["device"] << new_disk["key"]
            end
          end

          it "returns nil, nil" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to be_nil
            expect(unit_number).to    be_nil
          end
        end
      end

      context "with 2 pvscsi controllers" do
        before(:each) do
          pci_controller = miq_vim_vm["config"]["hardware"]["device"].detect { |dev| dev["key"] == "100" }
          pci_controller["device"] = []

          Array.new(2) do |i|
            pvscsi = VimHash.new("ParaVirtualSCSIController") do |scsi|
              scsi["key"]                = "100#{i}"
              scsi["deviceInfo"]         = {
                "label"   => "SCSI controller 0",
                "summary" => "VMware paravirtual SCSI"
              }
              scsi["scsiCtlrUnitNumber"] = "7"
              scsi["controllerKey"]      = "100"
              scsi["unitNumber"]         = i.to_s
              scsi["busNumber"]          = "0"
            end

            miq_vim_vm["config"]["hardware"]["device"] << pvscsi
            pci_controller["device"] << pvscsi["key"]
          end
        end

        context "with 1 free unit on the first controller" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            [*0..6, *9..15].each do |i|
              new_disk = VimHash.new("VirtualDisk") do |disk|
                disk["key"]           = "200#{i}"
                disk["controllerKey"] = "1000"
                disk["unitNumber"]    = i.to_s
              end

              miq_vim_vm["config"]["hardware"]["device"] << new_disk
              scsi_controller["device"] << new_disk["key"]
            end
          end

          it "picks the free unit on the first controller" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1000")
            expect(unit_number).to    eq(8)
          end
        end

        context "with the first controller full" do
          before(:each) do
            scsi_controller = miq_vim_vm["config"]["hardware"]["device"].find { |dev| dev["key"] == "1000" }
            scsi_controller["device"] = []

            [*0..6, *8..15].each do |i|
              new_disk = VimHash.new("VirtualDisk") do |disk|
                disk["key"]           = "200#{i}"
                disk["controllerKey"] = "1000"
                disk["unitNumber"]    = i.to_s
              end

              miq_vim_vm["config"]["hardware"]["device"] << new_disk
              scsi_controller["device"] << new_disk["key"]
            end
          end

          it "picks the first unit on the second controller" do
            controller_key, unit_number = @vim_vm.available_scsi_units.first
            expect(controller_key).to eq("1001")
            expect(unit_number).to    eq(0)
          end
        end
      end
    end
  end
end
