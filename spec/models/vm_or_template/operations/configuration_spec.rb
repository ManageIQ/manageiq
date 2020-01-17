RSpec.describe VmOrTemplate::Operations::Configuration do
  context "#raw_add_disk" do
    let(:disk_name) { "abc" }
    let(:disk_size) { "123" }

    context "when ext_management_system does not exist" do
      let(:vm) { FactoryBot.create(:vm_or_template) }

      it "raises an exception when does not find ext_management_system" do
        message = "VM has no EMS, unable to add disk"
        expect { vm.add_disk(disk_name, disk_size, {}) }.to raise_error(message)
      end
    end

    context "when ext_management_system exists" do
      let(:vm) { FactoryBot.create(:vm_or_template, :ext_management_system => ems) }
      let(:ems) { FactoryBot.create(:ext_management_system, :with_authentication) }
      let(:storage_name) { "test_storage" }
      let(:storage) { FactoryBot.create(:storage, :name => storage_name) }
      let!(:host) { FactoryBot.create(:host, :ext_management_system => ems).tap { |h| h.host_storages.create!(:storage => storage) } }

      context "when storage exists" do
        it "adds a disk on the storage" do
          expect(vm).to receive(:raw_add_disk).with(disk_name, disk_size, :datastore => storage_name).once
          vm.add_disk(disk_name, disk_size, :datastore => storage_name)
        end
      end
    end
  end

  context "#raw_remove_disk" do
    let(:disk_name) { "[datastore1] vm1/vm1.vmdk" }

    context "from an archived vm" do
      let(:vm) { FactoryBot.create(:vm_or_template) }

      it "raises an exception" do
        expect { vm.remove_disk(disk_name) }.to raise_error("VM has no EMS, unable to remove disk")
      end
    end

    context "from an active vm" do
      let(:ems) { FactoryBot.create(:ext_management_system) }
      let(:vm)  { FactoryBot.create(:vm_or_template, :ext_management_system => ems) }

      it "defaults to delete the backing file" do
        expected_options = {}
        expect(vm).to receive(:raw_remove_disk).with(disk_name, expected_options)
        vm.remove_disk(disk_name)
      end

      it "can override the delete backing file option" do
        expected_options = {:delete_backing => false}

        expect(vm).to receive(:raw_remove_disk).with(disk_name, expected_options)
        vm.remove_disk(disk_name, :delete_backing => false)
      end
    end
  end
end
