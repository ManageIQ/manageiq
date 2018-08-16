describe EmsRefresh do
  context ".queue_refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
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

    it "with streaming refresh enabled doesn't queue a refresh" do
      allow(@ems).to receive(:supports_streaming_refresh?).and_return(true)
      target = @ems

      described_class.queue_refresh(target)
      expect(MiqQueue.count).to eq(0)
    end
  end

  context "stopping targets unbounded growth" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_vmware, :zone => zone)
    end

    let(:targets) do
      targets = []
      (0..996).each do |i|
        targets << ManagerRefresh::Target.load(
          :manager_id  => @ems.id,
          :association => :vms,
          :manager_ref => {:ems_ref => "vm_1"},
          :event_id    => i,
          :options     => {:opt1 => "opt#{i}", :opt2 => "opt2"}
        )
      end

      targets << vm_target
      targets << host_target
      targets << @ems
      targets
    end

    let(:vm_target) { FactoryGirl.create(:vm_vmware, :ext_management_system => @ems) }
    let(:host_target) { FactoryGirl.create(:host_vmware, :ext_management_system => @ems) }

    it "doesn't call uniq on targets if size is <= 1000" do
      described_class.queue_refresh(targets)

      expect(MiqQueue.last.data.size).to eq(1_000)
    end

    it "uniques targets if next queuing breaches size 1000" do
      described_class.queue_refresh(targets)
      described_class.queue_refresh([host_target, vm_target, @ems])

      expect(MiqQueue.last.data.size).to eq(4)
      described_class.queue_refresh(targets)
      expect(MiqQueue.last.data.size).to eq(4)
    end

    it "uniques targets if queuing breaches size 1000" do
      # We need different Vm, since targets are uniqued before queueing
      described_class.queue_refresh(targets << FactoryGirl.create(:vm_vmware, :ext_management_system => @ems))

      expect(MiqQueue.last.data.size).to eq(5)
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

      it "sets the queue callback correctly" do
        task_ids = described_class.queue_refresh_task(target1)
        described_class.queue_refresh_task(target2)

        queue_item = MiqQueue.find_by(:task_id => task_ids.first.to_s)
        expect(queue_item.miq_callback[:class_name]).to eq("MiqTask")
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

    context "task name" do
      let(:vm1) { FactoryGirl.create(:vm_vmware, :ext_management_system => @ems) }
      let(:vm2) { FactoryGirl.create(:vm_vmware, :ext_management_system => @ems) }
      it "uses targets' short classnames to compose task name" do
        task_ids = described_class.queue_refresh_task([vm1, vm2])
        task_name = MiqTask.find(task_ids.first).name
        expect(task_name).to include([vm1.class.name.demodulize, vm1.id].to_s)
        expect(task_name).to include([vm2.class.name.demodulize, vm1.id].to_s)
      end
    end

    describe ".create_refresh_task" do
      it "create refresh task and trancates task name to 255 symbols" do
        vm = FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => @ems)
        targets = Array.new(500) { [vm.class.name, vm.id] }
        task_name = described_class.send(:create_refresh_task, @ems, targets).name
        expect(task_name.include?(@ems.name)).to eq true
        expect(task_name.length).to eq 255
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
    expect(q_all[0].data).to eq(expected_targets.collect { |t| [t.class.name, t.id] })
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

  context '.refresh_new_target' do
    let(:ems) do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      FactoryGirl.create(:ems_vmware, :zone => zone)
    end

    context 'targeting a new vm' do
      let(:vm_hash) do
        {
          :type        => ManageIQ::Providers::InfraManager::Vm.name,
          :ems_ref     => 'vm-123',
          :ems_ref_obj => 'vm-123',
          :uid_ems     => 'vm-123',
          :name        => 'new-vm',
          :vendor      => 'unknown'
        }
      end

      it 'creates the new record' do
        target_hash  = {:vms => [vm_hash]}
        target_klass = vm_hash[:type].constantize
        target_find  = {:uid_ems => vm_hash[:uid_ems]}

        expect(ems.refresher).to receive(:refresh)
        described_class.refresh_new_target(ems.id, target_hash, target_klass, target_find)

        new_vm = target_klass.find_by(target_find)
        expect(new_vm).to have_attributes(vm_hash)
      end

      context 'on an existing host' do
        let(:host) { FactoryGirl.create(:host_with_ref, :ext_management_system => ems) }

        it 'links the new vm to the existing host' do
          target_hash = {
            :hosts => [{:ems_ref => host.ems_ref}]
          }

          vm_hash[:host] = target_hash[:hosts].first
          target_hash[:vms] = [vm_hash]

          target_find  = {:uid_ems => vm_hash[:uid_ems]}
          target_klass = vm_hash[:type].constantize

          expect(ems.refresher).to receive(:refresh)
          described_class.refresh_new_target(ems.id, target_hash, target_klass, target_find)

          new_vm = target_klass.find_by(target_find)
          expect(new_vm.host).to eq(host)
        end
      end
    end

    context 'targeting an existing vm' do
      let(:vm) { FactoryGirl.create(:vm_with_ref, :ext_management_system => ems) }

      it "doesn't try to create a new record" do
        vm_hash = {
          :ems_ref => vm.ems_ref,
          :uid_ems => vm.uid_ems,
          :type    => vm.class.name
        }
        target_hash  = {:vms => [vm_hash]}
        target_klass = vm_hash[:type].constantize
        target_find  = {:uid_ems => vm_hash[:uid_ems]}

        expect(ems.vms_and_templates.klass).not_to receive(:new)
        expect(ems.refresher).to receive(:refresh)

        described_class.refresh_new_target(ems.id, target_hash, target_klass, target_find)
      end
    end

    context 'targeting an archived vm' do
      let(:vm) { FactoryGirl.create(:vm_with_ref, :ems_id => nil) }

      it 'adopts the existing vm' do
        vm_hash = {
          :ems_ref => vm.ems_ref,
          :uid_ems => vm.uid_ems,
          :type    => vm.class.name
        }
        target_hash  = {:vms => [vm_hash]}
        target_klass = vm_hash[:type].constantize
        target_find  = {:uid_ems => vm_hash[:uid_ems]}

        expect(ems.refresher).to receive(:refresh)

        described_class.refresh_new_target(ems.id, target_hash, target_klass, target_find)

        vm.reload
        expect(vm.ext_management_system).to eq(ems)
      end
    end
  end

  describe '.queue_merge' do
    let(:ems) { FactoryGirl.create(:ems_vmware, :name => "ems_vmware1") }
    let(:vm)  { FactoryGirl.create(:vm_vmware, :name => "vm_vmware1", :ext_management_system => ems) }

    it 'sends the command to queue' do
      EmsRefresh.queue_merge([vm], ems)
      expect(MiqQueue.count).to eq(1)
    end

    context "task creation" do
      before do
        @miq_task = FactoryGirl.create(:miq_task)
        allow(EmsRefresh).to receive(:create_refresh_task).and_return(@miq_task)
      end

      it 'returns id of MiqTask linked to queued item' do
        task_id = EmsRefresh.queue_merge([vm], ems, true)
        expect(task_id).to eq @miq_task.id
      end

      it 'links created task with queued item' do
        task_id = EmsRefresh.queue_merge([vm], ems)
        queue_item = MiqQueue.find_by(:method_name => 'refresh', :role => "ems_inventory")
        expect(queue_item.miq_task_id).to eq task_id
      end
    end
  end
end
