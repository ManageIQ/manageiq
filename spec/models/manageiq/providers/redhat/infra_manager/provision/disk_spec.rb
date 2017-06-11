describe ManageIQ::Providers::Redhat::InfraManager::Provision::Disk do
  let(:ems)           { FactoryGirl.create(:ems_redhat_with_authentication) }
  let(:template)      { FactoryGirl.create(:template_redhat, :ext_management_system => ems) }
  let(:rhevm_vm)      { FactoryGirl.build(:vm_redhat) }
  let(:vm)            { FactoryGirl.build(:vm_redhat, :ext_management_system => ems) }
  let(:storage)       { FactoryGirl.create(:storage_nfs, :ems_ref => "http://example.com/storages/XYZ") }

  let(:disks_spec) do
    [
      {
        :disk_size_in_mb  => "33",
        :persistent       => true,
        :thin_provisioned => true,
        :dependent        => true,
        :bootable         => false,
        :datastore        => storage.name
      }
    ]
  end

  let(:options) do
    {
      :src_vm_id      => template.id,
      :vm_auto_start  => true,
      :vm_description => "some description",
      :vm_target_name => "test_vm_1",
      :disk_scsi      => disks_spec
    }
  end

  let(:expected_requested_disks) do
    [
      {
        :bootable  => false,
        :interface => "VIRTIO",
        :active    => true,
        :disk      => {
          :name             => nil,
          :provisioned_size => 0,
          :sparse           => false,
          :format           => "raw",
          :storage_domains  => [{ :id=>"XYZ" }]
        }
      }
    ]
  end

  before do
    @task = FactoryGirl.build(:miq_provision_redhat,
                              :source      => template,
                              :destination => vm,
                              :state       => 'pending',
                              :status      => 'Ok',
                              :options     => options
                             )
  end

  context "#configure_dialog_disks" do
    it "adds disks spec as specified in the request" do
      allow(@task).to receive(:find_storage!).and_return(storage)
      @task.configure_dialog_disks

      expect(@task.options[:disks_add]).to eq(expected_requested_disks)
    end

    context "no disks were specified in the request" do
      let(:options) do
        {
          :src_vm_id => template.id
        }
      end

      it "inherits the disks from the template" do
        expect(@task).not_to receive(:prepare_disks_for_add)
        @task.configure_dialog_disks

        expect(@task.options[:disks_add]).to eq(nil)
      end
    end

    context "storage is missing" do
      let(:storage) { double("storage", :name => nil) }

      it "should fail due to a missing datastore" do
        expect { @task.configure_dialog_disks }.to raise_error(MiqException::MiqProvisionError)
      end
    end

    context "storage is unknown" do
      let(:storage) { double("storage", :name => "no such datastore") }

      it "should fail due to a non-existing datastore" do
        expect { @task.configure_dialog_disks }.to raise_error(MiqException::MiqProvisionError)
      end
    end
  end

  context "#configure_disks" do
    it "adds disks as specified in the request" do
      allow(@task).to receive(:find_storage!).and_return(storage)
      expect(@task).to receive(:add_disks).with(expected_requested_disks).once
      expect(@task).to receive(:poll_add_disks_complete).once

      @task.configure_disks
    end

    context "no disks were specified in the request" do
      let(:options) do
        { :src_vm_id => template.id }
      end

      it "inherits the disks from the template" do
        expect(@task).not_to receive(:add_disks)
        expect(@task).to receive(:customize_guest).once

        @task.configure_disks
      end
    end
  end

  context "#destination_disks_locked?" do
    let(:disk_status) { "locked" }
    let(:disk) { double("disk", :status => disk_status, :id => 1) }
    let(:disk_attachments_service) { double("disk_attachments_service", :add => nil, :list => [disk]) }
    let(:vm_service) { double("vm_service", :disk_attachments_service => disk_attachments_service) }
    let(:vms_service) { double("vms_service", :vm_service => vm_service) }
    let(:disk_service) { double("disk_service", :get => disk) }
    let(:disks_service) { double("disks_service", :disk_service => disk_service) }
    let(:system_service) { double("system_service", :vms_service => vms_service, :disks_service => disks_service) }
    let(:connection) { double("connection", :system_service => system_service) }

    before do
      allow(vm).to receive(:with_provider_object).and_yield(rhevm_vm)
      allow(ems).to receive(:with_provider_connection).with(:version => 4).and_yield(connection)
    end

    it "returns true if there are locked disks" do
      expect(@task.destination_disks_locked?).to eq(true)
    end

    context "with no locked disks" do
      let(:disk_status) { "ok" }

      it "returns false if there aren't any locked disks" do
        expect(@task.destination_disks_locked?).to eq(false)
      end
    end
  end

  context "#poll_add_disks_complete" do
    before do
      allow(@task).to receive(:update_and_notify_parent)
    end

    it "calls customize guest when disks are not locked" do
      allow(@task).to receive(:destination_disks_locked?).and_return(false)
      expect(@task).to receive(:customize_guest)

      @task.poll_add_disks_complete
    end

    it "keeps checking disks status while they are locked" do
      allow(@task).to receive(:destination_disks_locked?).and_return(true)
      expect(@task).to receive(:requeue_phase)

      @task.poll_add_disks_complete
    end
  end

  context "#find_storage!" do
    let(:storage_name) { "test_storage" }
    let(:storages) { double("storages") }
    let(:host) { double("host", :writable_storages => storages) }
    let(:hosts) { [host] }

    before do
      allow(ems).to receive(:hosts).and_return(hosts)
    end

    context "when storage exists" do
      let(:storage) { FactoryGirl.create(:storage_nfs, :name => storage_name) }

      # storage = ext_management_system.hosts.detect { |h| h.writable_storages.find_by(:name => storage_name) }
      it "finds a storage by its name" do
        allow(storages).to receive(:find_by).with(:name => storage_name).and_return(storage)
        disk_spec = { :datastore => storage_name }

        expect(@task.send(:find_storage!, disk_spec)).to eq(storage)
      end
    end

    context "when storage does not exist" do
      it "raises an exception when doesn't find storage by its name" do
        allow(storages).to receive(:find_by).with(:name => storage_name).and_return(nil)
        disk_spec = { :datastore => storage_name }

        expect { @task.send(:find_storage!, disk_spec) }.to raise_error(MiqException::MiqProvisionError)
      end

      it "raises an exception when doesn't find storage without specifying name" do
        expect { @task.send(:find_storage!, {}) }.to raise_error(MiqException::MiqProvisionError)
      end
    end
  end
end
