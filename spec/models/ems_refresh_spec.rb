describe EmsRefresh do
  context ".queue_refresh" do
    before(:each) do
      guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_vmware, :zone => zone)
    end

    it "with Ems" do
      target = @ems
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Host" do
      target = FactoryGirl.create(:host_vmware, :ext_management_system => @ems)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Host acting as an Ems" do
      target = FactoryGirl.create(:host_microsoft)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Vm" do
      target = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Storage" do
      allow_any_instance_of(Storage).to receive_messages(:ext_management_systems => [@ems])
      target = FactoryGirl.create(:storage_vmware)
      queue_refresh_and_assert_queue_item(target, [target])
    end

    it "with Vm and an item already on the queue" do
      target = @ems
      queue_refresh_and_assert_queue_item(target, [target])
      target2 = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems)
      queue_refresh_and_assert_queue_item(target2, [target, target2])
    end

    def queue_refresh_and_assert_queue_item(target, expected_targets)
      described_class.queue_refresh(target)

      q_all = MiqQueue.all
      expect(q_all.length).to eq(1)
      expect(q_all[0].args).to eq([expected_targets.collect { |t| [t.class.name, t.id] }])
      expect(q_all[0].class_name).to eq(described_class.name)
      expect(q_all[0].method_name).to eq('refresh')
      expect(q_all[0].role).to eq("ems_inventory")
    end
  end

  context ".get_ar_objects" do
    it "array of class/ids pairs" do
      ems1 = FactoryGirl.create(:ems_vmware,     :name => "ems_vmware1")
      ems2 = FactoryGirl.create(:ems_redhat, :name => "ems_redhat1")
      pairs = [
        [ems1.class, ems1.id],
        [ems2.class, ems2.id]
      ]

      expect(described_class.get_ar_objects(pairs)).to match_array([ems1, ems2])
    end
  end

  context ".refresh" do
    it "accepts VMs" do
      ems = FactoryGirl.create(:ems_vmware, :name => "ems_vmware1")
      vm1 = FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => ems)
      vm2 = FactoryGirl.create(:vm_vmware, :name => "vm_vmware2", :ext_management_system => ems)
      expect(ManageIQ::Providers::Vmware::InfraManager::Refresher).to receive(:refresh) do |args|
        # Refresh code doesn't care about args order so neither does the test
        # TODO: use array_including in rspec 3
        (args - [vm2, vm1]).empty?
      end

      EmsRefresh.refresh([
        [vm1.class, vm1.id],
        [vm2.class, vm2.id],
      ])
    end

    it "ignores an EMS-less (archived) VM" do
      ems = FactoryGirl.create(:ems_vmware, :name => "ems_vmware1")
      vm1 = FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => ems)
      vm2 = FactoryGirl.create(:vm_vmware, :name => "vm_vmware2", :ext_management_system => nil)
      expect(ManageIQ::Providers::Vmware::InfraManager::Refresher).to receive(:refresh).with([vm1])
      EmsRefresh.refresh([
        [vm1.class, vm1.id],
        [vm2.class, vm2.id],
      ])
    end
  end

  context '.queue_merge_async' do
    let(:ems) { FactoryGirl.create(:ems_vmware, :name => "ems_vmware1") }
    let(:vm)  { FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => ems) }

    it 'sends the command to queue' do
      EmsRefresh.queue_merge_async([vm], ems)
      expect(MiqQueue.count).to eq(1)
    end
  end

  context '.queue_merge_sync' do
    let(:ems) { FactoryGirl.create(:ems_vmware, :name => "ems_vmware1") }
    let(:vm)  { FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => ems) }

    it 'sends the refresh command to queue' do
      allow(MiqQueue).to receive(:find_by).and_return(nil)
      EmsRefresh.queue_merge_sync([vm], ems)
      expect(MiqQueue.count).to eq(1)
    end

    it 'returns after the refresh command is processed' do
      allow(MiqQueue).to receive(:find_by).and_return(1, nil)
      expect(EmsRefresh).to receive(:sleep)
      EmsRefresh.queue_merge_sync([vm], ems)
    end
  end
end
