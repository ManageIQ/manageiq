require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. VMwareWebService})))
require 'MiqVim'

describe MiqVimVm do
  context 'snapshot disk size check' do
    before(:each) do
      @inv_obj = mock
      @inv_obj.stub(:sic).and_return(nil)
      @inv_obj.stub(:localVmPath).and_return('/test-vm/test-vm.vmx')

      vmh = {
          'summary' => {
              'config' => {
                  'name' => VimString.new('test-vm'),
                  'uuid' => VimString.new('502fee93-3744-2d43-6a02-ddd0af96868c'),
                  'vmPathName' => VimString.new('[local-dev] test-vm/test-vm.vmx')
              },
          'vm' => VimString.new('vm-100'),
          'runtime' => {}
          }
      }
      @vim_vm = MiqVimVm.new(@inv_obj, vmh)
    end

    context "snapshot_directory_mor" do
      before(:each) do
        @inv_obj.stub(:path2dsName).and_return(VimString.new('path2dsName'))
        @inv_obj.stub(:dsName2mo_local).and_return(VimString.new('dsName2mo_local'))
      end

      context "API 4.x" do
        before(:each) do
          @inv_obj.stub(:apiVersion).and_return(VimString.new('4.1'))
        end

        it "snapshot_directory_mor" do
          @vim_vm.snapshot_directory_mor({}).should == 'dsName2mo_local'
        end
      end

      context "API 5.x" do
        before(:each) do
          @inv_obj.stub(:apiVersion).and_return(VimString.new('5.0'))
          @redoNotWithParent = VimHash.new do |vh|
            vh.key =   'snapshot.redoNotWithParent'
            vh.value = 'false'
          end
          @config = {'config' => {'extraConfig' => [@redoNotWithParent]}}
        end

        it "without redoNotWithParent" do
          config = {'config' => {'extraConfig' => []}}
          @vim_vm.snapshot_directory_mor(config).should be_nil
        end

        it "API 5.x - with redoNotWithParent = false" do
          @vim_vm.snapshot_directory_mor(@config).should be_nil
        end

        it "API 5.x - with redoNotWithParent = true" do
          @redoNotWithParent['value'] = true
          @vim_vm.snapshot_directory_mor(@config).should == 'dsName2mo_local'
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

        @inv_obj.stub(:getMoProp_local).and_return(ds_summary)
      end

      it "check_disk_space - 100 percent, small disk" do
        max_disk_space_in_kb = 1000
        @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 100)
      end

      it "check_disk_space - 100 percent, large disk" do
        max_disk_space_in_kb = 10000
        lambda{ @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 100)}.should raise_error(MiqException::MiqVmSnapshotError)
      end

      it "check_disk_space - 0 percent" do
        max_disk_space_in_kb = 10000
        lambda{ @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 0)}.should_not raise_error(MiqException::MiqVmSnapshotError)
      end

      it "check_disk_space - 10 percent" do
        max_disk_space_in_kb = 10000
        lambda{ @vim_vm.check_disk_space('create', @ds_mor, max_disk_space_in_kb, 10)}.should_not raise_error(MiqException::MiqVmSnapshotError)
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
        result.should have(2).things
        result['datastore-001'].should == 100
        result['datastore-002'].should == 200
      end

      it "single-datastore" do
        @disk2.backing['datastore'] = 'datastore-001'
        result = @vim_vm.disk_space_per_datastore(@devices, nil)
        result.should have(1).thing
        result['datastore-001'].should == 300
      end

      it "snapshot directory override" do
        result = @vim_vm.disk_space_per_datastore(@devices, 'datastore-snap')
        result.should have(1).thing
        result['datastore-snap'].should == 300
      end
    end
  end
end
