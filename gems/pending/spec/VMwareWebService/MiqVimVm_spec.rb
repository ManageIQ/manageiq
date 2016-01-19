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
  end
end
