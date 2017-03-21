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

    it "with ManagerRefresh::Target" do
      target = ManagerRefresh::Target.load(
        :manager_id  => @ems.id,
        :association => :vms,
        :manager_ref => {:ems_ref => "vm_1"},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

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
  end

  context ".queue_refresh_task" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems  = FactoryGirl.create(:ems_vmware, :zone => zone)
      @ems2 = FactoryGirl.create(:ems_vmware, :zone => zone)
    end

    context "with a refresh already on the queue" do
      let(:target1) { @ems }
      let(:target2) { FactoryGirl.create(:vm_vmware, :ext_management_system => @ems) }

      it "only creates one task" do
        described_class.queue_refresh_task(target1)
        described_class.queue_refresh_task(target2)

        expect(MiqTask.count).to eq(1)
      end

      it "returns the first task" do
        task_ids = described_class.queue_refresh_task(target1)
        task_ids2 = described_class.queue_refresh_task(target2)

        expect(task_ids.length).to  eq(1)
        expect(task_ids2.length).to eq(1)
        expect(task_ids.first).to   eq(task_ids2.first)
      end
    end

    context "with Vms on different EMSs" do
      let(:vm1) { FactoryGirl.create(:vm_vmware, :ext_management_system => @ems) }
      let(:vm2) { FactoryGirl.create(:vm_vmware, :ext_management_system => @ems2) }
      it "returns a task for each EMS" do
        task_ids = described_class.queue_refresh_task([vm1, vm2])
        expect(task_ids.length).to eq(2)
      end
    end
  end

  def queue_refresh_and_assert_queue_item(target, expected_targets)
    described_class.queue_refresh(target)
    assert_queue_item(expected_targets)
  end

  def assert_queue_item(expected_targets)
    q_all = MiqQueue.all
    expect(q_all.length).to eq(1)
    expect(q_all[0].args).to eq([expected_targets.collect { |t| [t.class.name, t.id] }])
    expect(q_all[0].class_name).to eq(described_class.name)
    expect(q_all[0].method_name).to eq('refresh')
    expect(q_all[0].role).to eq("ems_inventory")
  end

  context ".get_target_objects" do
    it "array of class/ids pairs" do
      ems1 = FactoryGirl.create(:ems_vmware, :name => "ems_vmware1")
      ems2 = FactoryGirl.create(:ems_redhat, :name => "ems_redhat1")
      pairs = [
        [ems1.class, ems1.id],
        [ems2.class, ems2.id]
      ]

      expect(described_class.get_target_objects(pairs)).to match_array([ems1, ems2])
    end

    it "array of class/hash pairs for ManagerRefresh::Target objects" do
      ems1 = FactoryGirl.create(:ems_vmware, :name => "ems_vmware1")
      ems2 = FactoryGirl.create(:ems_redhat, :name => "ems_redhat1")

      target1     = ManagerRefresh::Target.load(:manager_id  => ems1.id,
                                                :association => :vms,
                                                :manager_ref => {:ems_ref => "vm1"})
      target2     = ManagerRefresh::Target.load(:manager_id  => ems2.id,
                                                :association => :network_ports,
                                                :manager_ref => {:ems_ref => "network_port_1"})
      target3     = ManagerRefresh::Target.new(:manager_id  => ems1.id,
                                               :association => :vms,
                                               :manager_ref => {:ems_ref => "vm2"})
      target1_dup = ManagerRefresh::Target.load(:manager_id  => ems1.id,
                                                :association => :vms,
                                                :manager_ref => {:ems_ref => "vm1"})
      pairs = [
        [target1.class, target1.id],
        [target2.class, target2.id],
        [target3.class, target3.id],
        [target1_dup.class, target1_dup.id],
      ]

      expect(described_class.get_target_objects(pairs).map(&:dump)).to match_array([target1, target2, target3].map(&:dump))
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

  context '.queue_merge' do
    let(:ems) { FactoryGirl.create(:ems_vmware, :name => "ems_vmware1") }
    let(:vm)  { FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => ems) }

    it 'sends the command to queue' do
      EmsRefresh.queue_merge([vm], ems)
      expect(MiqQueue.count).to eq(1)
    end
  end
end
