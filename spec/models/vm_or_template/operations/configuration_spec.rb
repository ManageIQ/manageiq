describe VmOrTemplate::Operations::Configuration do
  context "#raw_add_disk" do
    let(:disk_name) { "abc" }
    let(:disk_size) { "123" }

    context "when ext_management_system does not exist" do
      let(:vm) { FactoryGirl.create(:vm_or_template) }

      it "raises an exception when does not find ext_management_system" do
        message = "VM has no EMS, unable to add disk"
        expect { vm.raw_add_disk(disk_name, disk_size, {}) }.to raise_error(message)
      end
    end

    context "when ext_management_system exists" do
      let(:vm) { FactoryGirl.create(:vm_or_template, :ext_management_system => ems) }
      let(:ems) { FactoryGirl.create(:ext_management_system) }
      let(:storage_name) { "test_storage" }
      let(:storage) { FactoryGirl.create(:storage, :name => storage_name) }
      let(:storages) { double("storages") }
      let(:host) { double("host", :writable_storages => storages) }
      let(:hosts) { [host] }

      before do
        allow(ems).to receive(:hosts).and_return(hosts)
      end

      context "when storage exists" do
        it "adds a disk on the storage" do
          allow(storages).to receive(:find_by).with(:name => storage_name).and_return(storage)
          allow(ems).to receive(:authentication_status_ok?).and_return(true)
          allow(ems).to receive(:vm_add_disk)

          expected_options = {
            :diskName        => disk_name,
            :diskSize        => disk_size,
            :thinProvisioned => nil,
            :dependent       => nil,
            :persistent      => nil,
            :bootable        => nil,
            :datastore       => storage,
            :interface       => nil
          }
          expect(vm).to receive(:run_command_via_parent).with(:vm_add_disk, expected_options).once
          vm.raw_add_disk(disk_name, disk_size, :datastore => storage_name)
        end
      end

      context "when storage does not exist" do
        it "raises an exception when doesn't find storage by its name" do
          allow(storages).to receive(:find_by).with(:name => storage_name).and_return(nil)

          message = "Datastore does not exist or cannot be accessed, unable to add disk"
          expect { vm.raw_add_disk(disk_name, disk_size, :datastore => storage_name) }.to raise_error(message)
        end
      end
    end
  end

  context "#raw_remove_disk" do
    let(:disk_name) { "[datastore1] vm1/vm1.vmdk" }

    context "from an archived vm" do
      let(:vm) { FactoryGirl.create(:vm_or_template) }

      it "raises an exception" do
        expect { vm.raw_remove_disk(disk_name) }.to raise_error("VM has no EMS, unable to remove disk")
      end
    end

    context "from an active vm" do
      let(:ems) { FactoryGirl.create(:ext_management_system) }
      let(:vm)  { FactoryGirl.create(:vm_or_template, :ext_management_system => ems) }

      it "defaults to delete the backing file" do
        expected_options = {
          :diskName       => disk_name,
          :delete_backing => true,
        }

        expect(vm).to receive(:run_command_via_parent).with(:vm_remove_disk, expected_options)
        vm.raw_remove_disk(disk_name)
      end

      it "can override the delete backing file option" do
        expected_options = {
          :diskName       => disk_name,
          :delete_backing => false,
        }

        expect(vm).to receive(:run_command_via_parent).with(:vm_remove_disk, expected_options)
        vm.raw_remove_disk(disk_name, :delete_backing => false)
      end
    end
  end
end
