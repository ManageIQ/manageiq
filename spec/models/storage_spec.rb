describe Storage do
  describe "#total_unregistered_vms" do
    let(:ext_management_system)  { FactoryGirl.create(:ext_management_system) }
    let(:host)                   { FactoryGirl.create(:host) }
    let(:storage)                { FactoryGirl.create(:storage) }
    let!(:vm_registered_1) { FactoryGirl.create(:vm, :storage => storage, :ext_management_system => ext_management_system, :host => host) }
    let!(:vm_registered_2) { FactoryGirl.create(:vm, :storage => storage, :host => host) }
    let!(:vm_unregistered) { FactoryGirl.create(:vm, :storage => storage, :ext_management_system => ext_management_system) }

    it 'returns only unregistred vms' do
      expect(storage.total_unregistered_vms).to eq(1)
      expect(storage.total_unregistered_vms).to eq(storage.unregistered_vms.size)
    end
  end

  it "#scan_watchdog_interval" do
    stub_settings(:storage => {'watchdog_interval' => '5.minutes'})
    expect(Storage.scan_watchdog_interval).to eq(5.minutes)
  end

  it "#max_qitems_per_scan_request" do
    stub_settings(:storage => {'max_qitems_per_scan_request' => 3})
    expect(Storage.max_qitems_per_scan_request).to eq(3)
  end

  it "#scan_collection_timeout" do
    stub_settings(:storage => {:collection => {:timeout => 3}})
    expect(Storage.scan_collection_timeout).to eq(3)
  end

  it "#scan_watchdog_deliver_on" do
    scan_watchdog_interval = 7.minutes
    allow(Storage).to receive_messages(:scan_watchdog_interval => scan_watchdog_interval)
    start = Time.parse("Sun March 10 01:00:00 UTC 2010")
    Timecop.travel(start) do
      expect(Storage.scan_watchdog_deliver_on - (start + scan_watchdog_interval)).to be_within(0.001).of(0.0)
    end
  end

  it "#scan_complete?" do
    miq_task = FactoryGirl.create(:miq_task)
    miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
    miq_task.context_data[:targets]  = [123, 456, 789]
    miq_task.context_data[:complete] = []
    expect(Storage.scan_complete?(miq_task)).to be_falsey

    miq_task.context_data[:complete]  = [123, 456, 789]
    expect(Storage.scan_complete?(miq_task)).to be_truthy
  end

  it "#scan_complete_message" do
    miq_task = FactoryGirl.create(:miq_task)
    miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
    miq_task.context_data[:targets]  = [123, 456, 789]
    expect(Storage.scan_complete_message(miq_task)).to eq("SmartState Analysis for 3 storages complete")
  end

  it "#scan_update_message" do
    miq_task = FactoryGirl.create(:miq_task)
    miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
    miq_task.context_data[:targets]  = [123, 456, 789]
    miq_task.context_data[:complete] = [123]
    miq_task.context_data[:pending][789] = 98765
    expect(Storage.scan_update_message(miq_task)).to eq("1 Storage Scans Pending; 1 of 3 Scans Complete")
  end

  context "with multiple storages" do
    before do
      @server = EvmSpecHelper.local_miq_server
      @zone   = @server.zone

      @zone2     = FactoryGirl.create(:zone, :name => 'Bedrock')
      @ems1      = FactoryGirl.create(:ems_vmware_with_valid_authentication, :name => "test_vcenter1",     :zone => @zone)
      @ems2      = FactoryGirl.create(:ems_vmware_with_authentication,       :name => "test_vcenter2",     :zone => @zone2)
      @storage1  = FactoryGirl.create(:storage,               :name => "test_storage_vmfs", :store_type => "VMFS")
      @storage2  = FactoryGirl.create(:storage,               :name => "test_storage_nfs",  :store_type => "NFS")
      @storage3  = FactoryGirl.create(:storage,               :name => "test_storage_foo",  :store_type => "FOO")
      @host1     = FactoryGirl.create(:host, :name => "test_host1", :hostname => "test_host1", :state => 'on', :ems_id => @ems1.id, :storages => [@storage1, @storage3])
      @host2     = FactoryGirl.create(:host, :name => "test_host2", :hostname => "test_host2", :state => 'on', :ems_id => @ems2.id, :storages => [@storage2, @storage3])
    end

    it "#active_hosts_in_zone" do
      expect(@storage1.active_hosts_in_zone(@zone.name)).to eq([@host1])
      expect(@storage1.active_hosts_in_zone(@zone2.name)).to eq([])
      expect(@storage2.active_hosts_in_zone(@zone.name)).to eq([])
      expect(@storage2.active_hosts_in_zone(@zone2.name)).to eq([@host2])
      expect(@storage3.active_hosts_in_zone(@zone.name)).to eq([@host1])
      expect(@storage3.active_hosts_in_zone(@zone2.name)).to eq([@host2])
    end

    it "#active_hosts" do
      expect(@storage1.active_hosts).to eq([@host1])
      expect(@storage2.active_hosts).to eq([@host2])
      expect(@storage3.active_hosts).to match_array [@host1, @host2]
    end

    it "#my_zone" do
      expect(@storage1.my_zone).to eq(@zone.name)
      expect(@storage2.my_zone).to eq(@zone2.name)
      expect(@storage3.my_zone).to eq(@zone.name)
    end

    it "#scan_queue_item" do
      scan_collection_timeout = 456
      allow(Storage).to receive_messages(:scan_collection_timeout => scan_collection_timeout)

      miq_task = FactoryGirl.create(:miq_task)
      qitem = @storage1.scan_queue_item(miq_task.id)

      expect(qitem.class_name).to eq(@storage1.class.name)
      expect(qitem.instance_id).to eq(@storage1.id)
      expect(qitem.method_name).to eq('smartstate_analysis')
      expect(qitem.args).to eq([miq_task.id])
      expect(qitem.msg_timeout).to eq(scan_collection_timeout)
      expect(qitem.zone).to eq(@storage1.my_zone)
      expect(qitem.role).to eq('ems_operations')
      expect(qitem.miq_callback).to eq({:class_name => @storage1.class.name, :instance_id => @storage1.id, :method_name => :scan_complete_callback, :args => [miq_task.id]})
    end

    it "#scan_storages_unprocessed" do
      miq_task = FactoryGirl.create(:miq_task)
      miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
      miq_task.context_data[:targets]  = [@storage1.id, @storage2.id, @storage3.id]
      miq_task.context_data[:complete] = []
      miq_task.context_data[:pending]  = {}
      expect(Storage.scan_storages_unprocessed(miq_task)).to match_array [@storage1.id, @storage2.id, @storage3.id]

      miq_task.context_data[:complete] = [@storage3.id]
      expect(Storage.scan_storages_unprocessed(miq_task)).to match_array [@storage1.id, @storage2.id]

      miq_task.context_data[:pending][@storage2.id] = 12345
      expect(Storage.scan_storages_unprocessed(miq_task)).to eq([@storage1.id])

      miq_task.context_data[:pending].delete(@storage2.id)
      expect(Storage.scan_storages_unprocessed(miq_task)).to match_array [@storage1.id, @storage2.id]

      miq_task.context_data[:complete]  = [@storage1.id, @storage2.id, @storage3.id]
      expect(Storage.scan_storages_unprocessed(miq_task)).to eq([])
    end

    it "#scan_queue_watchdog" do
      miq_task = FactoryGirl.create(:miq_task)
      deliver_on = Time.now.utc + 1.hour
      allow(Storage).to receive_messages(:scan_watchdog_deliver_on => deliver_on)
      watchdog = Storage.scan_queue_watchdog(miq_task.id)
      expect(watchdog.class_name).to eq('Storage')
      expect(watchdog.method_name).to eq('scan_watchdog')
      expect(watchdog.args).to eq([miq_task.id])
      expect(watchdog.zone).to eq(MiqServer.my_zone)
      expect(watchdog.deliver_on).to eq(deliver_on)
    end

    context "on an ems without credentials" do
      it "#scan will raise error" do
        expect { @storage2.scan }.to raise_error(MiqException::MiqStorageError)
      end
    end

    context "on a host with authentication status ok" do
      before do
        allow_any_instance_of(Authentication).to receive(:after_authentication_changed)
        FactoryGirl.create(:authentication, :resource => @host1, :status => "Valid")
      end

      it "#active_hosts_with_authentication_status_ok" do
        expect(@storage1.active_hosts_with_authentication_status_ok).to eq([@host1])
        expect(@storage2.active_hosts_with_authentication_status_ok).to eq([])
        expect(@storage3.active_hosts_with_authentication_status_ok).to eq([@host1])
      end

      it "#active_hosts_with_authentication_status_ok_in_zone" do
        expect(@storage1.active_hosts_with_authentication_status_ok_in_zone(@zone.name)).to eq([@host1])
        expect(@storage1.active_hosts_with_authentication_status_ok_in_zone(@zone2.name)).to eq([])
        expect(@storage2.active_hosts_with_authentication_status_ok_in_zone(@zone.name)).to eq([])
        expect(@storage2.active_hosts_with_authentication_status_ok_in_zone(@zone2.name)).to eq([])
        expect(@storage3.active_hosts_with_authentication_status_ok_in_zone(@zone.name)).to eq([@host1])
        expect(@storage3.active_hosts_with_authentication_status_ok_in_zone(@zone2.name)).to eq([])
      end
    end

    context "on an ems with authentication status ok" do
      it "#ext_management_systems" do
        expect(@storage1.ext_management_systems).to eq([@ems1])
        expect(@storage2.ext_management_systems).to eq([@ems2])
        expect(@storage3.ext_management_systems).to match_array [@ems1, @ems2]
      end

      it "#ext_management_systems_in_zone" do
        expect(@storage1.ext_management_systems_in_zone(@zone.name)).to eq([@ems1])
        expect(@storage1.ext_management_systems_in_zone(@zone2.name)).to eq([])
        expect(@storage2.ext_management_systems_in_zone(@zone.name)).to eq([])
        expect(@storage2.ext_management_systems_in_zone(@zone2.name)).to eq([@ems2])
        expect(@storage3.ext_management_systems_in_zone(@zone.name)).to eq([@ems1])
        expect(@storage3.ext_management_systems_in_zone(@zone2.name)).to eq([@ems2])
      end

      it "#ext_management_systems_with_authentication_status_ok" do
        expect(@storage1.ext_management_systems_with_authentication_status_ok).to eq([@ems1])
      end

      it "#ext_management_systems_with_authentication_status_ok_in_zone" do
        expect(@storage1.ext_management_systems_with_authentication_status_ok_in_zone(@zone.name)).to eq([@ems1])
        expect(@storage1.ext_management_systems_with_authentication_status_ok_in_zone(@zone2.name)).to eq([])
      end

      it "#scan" do
        expect { @storage3.scan }.to raise_error(MiqException::MiqUnsupportedStorage)

        expect(MiqEvent).to receive(:raise_evm_job_event).once
        @storage1.scan

        task = MiqTask.first
        expect(task.userid).to eq("system")
        expect(task.name).to eq("SmartState Analysis for [#{@storage1.name}]")

        message = MiqQueue.where(:method_name => "smartstate_analysis").first
        expect(message.instance_id).to eq(@storage1.id)
        expect(message.args).to eq([task.id])
        expect(message.zone).to eq(@zone.name)
        expect(message.role).to eq("ems_operations")
      end

      context "with performance capture disabled" do
        before do
          allow_any_instance_of(Storage).to receive_messages(:perf_capture_enabled? => false)
        end

        it "#scan_eligible_storages" do
          expect(Storage.scan_eligible_storages).to              be_empty
          expect(Storage.scan_eligible_storages(nil)).to         be_empty
          expect(Storage.scan_eligible_storages(@zone.name)).to  be_empty
          expect(Storage.scan_eligible_storages(@zone2.name)).to be_empty
        end

        it "#scan_timer" do
          expect(Storage).to receive(:scan_queue_watchdog).never
          miq_task  = Storage.scan_timer(nil)
          expect(miq_task).to be_nil
          expect(MiqTask.count).to eq(0)
          expect(MiqQueue.count).to eq(0)
        end
      end

      context "with performance capture enabled" do
        before do
          allow_any_instance_of(Storage).to receive_messages(:perf_capture_enabled? => true)
          allow(MiqEvent).to receive(:raise_evm_job_event)
        end

        it "#scan_eligible_storages" do
          expect(Storage.scan_eligible_storages).to              match_array [@storage1, @storage2]
          expect(Storage.scan_eligible_storages(nil)).to         match_array [@storage1, @storage2]
          expect(Storage.scan_eligible_storages(@zone.name)).to eq([@storage1])
          expect(Storage.scan_eligible_storages(@zone2.name)).to eq([@storage2])
        end

        it "#scan_queue" do
          bogus_id = @storage1.id - 1
          miq_task = FactoryGirl.create(:miq_task)
          miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
          miq_task.context_data[:targets]  = [bogus_id, @storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete] = []
          miq_task.context_data[:pending]  = {}
          miq_task.save!

          qitem1  = FactoryGirl.create(:miq_queue)
          allow_any_instance_of(Storage).to receive_messages(:scan_queue_item => qitem1)
          Storage.scan_queue(miq_task)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([])
          expect(miq_task.context_data[:pending].length).to eq(1)
          expect(miq_task.context_data[:pending][@storage1.id]).to eq(qitem1.id)

          miq_task.context_data[:complete] << @storage1.id
          miq_task.context_data[:pending].delete(@storage1.id)
          miq_task.save!
          qitem2  = FactoryGirl.create(:miq_queue)
          allow_any_instance_of(Storage).to receive_messages(:scan_queue_item => qitem2)
          Storage.scan_queue(miq_task)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([@storage1.id])
          expect(miq_task.context_data[:pending].length).to eq(1)
          expect(miq_task.context_data[:pending][@storage2.id]).to eq(qitem2.id)

          miq_task.context_data[:complete] << @storage2.id
          miq_task.context_data[:pending].delete(@storage2.id)
          miq_task.save!
          allow_any_instance_of(Storage).to receive(:scan_queue_item).and_raise(MiqException::MiqUnsupportedStorage)
          Storage.scan_queue(miq_task)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id])
          expect(miq_task.context_data[:complete]).to eq([@storage1.id, @storage2.id])
          expect(miq_task.context_data[:pending].length).to eq(0)
        end

        it "#scan_watchdog" do
          max_qitems_per_scan_request = 1
          allow(Storage).to receive_messages(:max_qitems_per_scan_request => max_qitems_per_scan_request)
          miq_task = FactoryGirl.create(:miq_task)
          miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
          miq_task.context_data[:targets]  = [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete] = []
          miq_task.context_data[:pending]  = {}
          miq_task.save!

          expect(Storage).to receive(:scan_queue_watchdog).with(miq_task.id).once
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([])
          expect(miq_task.context_data[:pending].length).to eq(0)

          qitem1  = FactoryGirl.create(:miq_queue)
          miq_task.context_data[:pending][@storage1.id] = qitem1.id
          miq_task.save!
          expect(Storage).to receive(:scan_queue_watchdog).with(miq_task.id).once
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([])
          expect(miq_task.context_data[:pending].length).to eq(1)
          expect(miq_task.context_data[:pending][@storage1.id]).to eq(qitem1.id)

          qitem1.destroy
          expect(Storage).to receive(:scan_queue).with(miq_task).once
          expect(Storage).to receive(:scan_queue_watchdog).with(miq_task.id).once
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([])
          expect(miq_task.context_data[:pending].length).to eq(0)

          miq_task.context_data[:complete] = [@storage1.id, @storage2.id, @storage3.id]
          miq_task.save!
          expect(Storage).to receive(:scan_queue).never
          expect(Storage).to receive(:scan_queue_watchdog).never
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:pending].length).to eq(0)
        end

        it "#scan_complete_callback" do
          miq_task = FactoryGirl.create(:miq_task)
          miq_task.context_data = {:targets => [], :complete => [], :pending  => {}}
          miq_task.context_data[:targets]  = [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete] = []
          miq_task.context_data[:pending][@storage1.id] = 123
          miq_task.save!
          expect(Storage).to receive(:scan_queue).with(miq_task).once
          @storage1.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([@storage1.id])
          expect(miq_task.context_data[:pending].length).to eq(0)
          expect(miq_task.pct_complete).to eq(33)

          miq_task.context_data[:pending][@storage2.id] = 456
          miq_task.save!
          expect(Storage).to receive(:scan_queue).with(miq_task).once
          @storage2.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([@storage1.id, @storage2.id])
          expect(miq_task.context_data[:pending].length).to eq(0)
          expect(miq_task.pct_complete).to eq(66)

          miq_task.context_data[:pending][@storage3.id] = 789
          miq_task.save!
          expect(Storage).to receive(:scan_queue).never
          expect_any_instance_of(MiqTask).to receive(:update_status).once
          @storage3.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
          miq_task.reload
          expect(miq_task.context_data[:targets]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:complete]).to eq([@storage1.id, @storage2.id, @storage3.id])
          expect(miq_task.context_data[:pending].length).to eq(0)
          expect(miq_task.pct_complete).to eq(100)

          miq_task.update_attributes!(:state => "Finished")
          miq_task.destroy
          expect(Storage).to receive(:scan_queue).never
          expect_any_instance_of(MiqTask).to receive(:update_status).never
          @storage1.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
        end

        it "#scan_timer" do
          expect(Storage).to receive(:scan_queue_watchdog).once
          allow(Storage).to receive(:scan_queue)
          miq_task  = Storage.scan_timer(nil)
          miq_tasks = MiqTask.all
          expect(miq_tasks.length).to eq(1)
          expect(miq_task).to eq(miq_tasks.first)
          expect(miq_task).not_to be_nil
          expect(miq_task.userid).to eq("system")
          expect(miq_task.name).to eq("SmartState Analysis for All Storages")
          expect(miq_task.state).to eq(MiqTask::STATE_QUEUED)
          cdata = miq_task.context_data
          expect(cdata[:targets]).to  match_array Storage.scan_eligible_storages.collect(&:id)
          expect(cdata[:complete]).to be_empty
          expect(cdata[:pending]).to  be_empty
        end

        it "#scan_timer(zone)" do
          miq_task = Storage.scan_timer(@zone.name)
          expect(miq_task.name).to eq("SmartState Analysis for All Storages in Zone \"#{@zone.name}\"")
          expect(miq_task.context_data[:targets]).to match_array Storage.scan_eligible_storages(@zone.name).collect(&:id)
        end
      end
    end
  end

  context "#is_available? for Smartstate Analysis" do
    before do
      @storage =  FactoryGirl.create(:storage)
    end

    it "returns true for VMware Storage when queried whether it supports smartstate analysis" do
      FactoryGirl.create(:host_vmware,
                         :ext_management_system => FactoryGirl.create(:ems_vmware_with_valid_authentication),
                         :storages              => [@storage])

      expect(@storage.supports_smartstate_analysis?).to eq(true)
    end

    it "returns false for non-vmware Storage when queried whether it supports smartstate analysis" do
      expect(@storage.supports_smartstate_analysis?).to_not eq(true)
    end
  end

  describe "#update_vm_perf" do
    it "will update a vm_perf with an attributes hash keyed with symbols" do
      storage = FactoryGirl.create(:storage)
      vm = FactoryGirl.create(:vm)
      metric_rollup = FactoryGirl.build(:metric_rollup)
      attrs = {:resource_name => "test vm"}

      storage.update_vm_perf(vm, metric_rollup, attrs)

      expect(metric_rollup.resource_name).to eq("test vm")
    end
  end

  describe "#count_of_vmdk_disk_files" do
    it "ignores the correct files" do
      FactoryGirl.create(:storage_file, :storage_id => 1, :ext_name => 'vmdk', :base_name => "good-stuff.vmdk")
      FactoryGirl.create(:storage_file, :storage_id => 2, :ext_name => 'dat', :base_name => "bad-stuff.dat")
      FactoryGirl.create(:storage_file, :storage_id => 3, :ext_name => 'vmdk', :base_name => "bad-flat.vmdk")
      FactoryGirl.create(:storage_file, :storage_id => 4, :ext_name => 'vmdk', :base_name => "bad-delta.vmdk")
      FactoryGirl.create(:storage_file, :storage_id => 5, :ext_name => 'vmdk', :base_name => "bad-123456.vmdk")
      FactoryGirl.create(:storage_file, :storage_id => 6, :ext_name => 'vmdk', :base_name => "good-11.vmdk")

      counts = Storage.count_of_vmdk_disk_files
      expect(counts[1]).to eq(1)
      expect(counts[2]).to eq(0)
      expect(counts[3]).to eq(0)
      expect(counts[4]).to eq(0)
      expect(counts[5]).to eq(0)
      expect(counts[6]).to eq(1)
    end
  end

  context "#is_available? for Smartstate Analysis" do
    before do
      @storage = FactoryGirl.create(:storage)
    end

    it "returns true for VMware Storage when queried whether it supports smartstate analysis" do
      FactoryGirl.create(:host_vmware,
                         :ext_management_system => FactoryGirl.create(:ems_vmware_with_valid_authentication),
                         :storages              => [@storage])
      expect(@storage.supports_smartstate_analysis?).to eq(true)
    end

    it "returns false for non-vmware Storage when queried whether it supports smartstate analysis" do
      expect(@storage.supports_smartstate_analysis?).to_not eq(true)
    end
  end
  describe "#smartstate_analysis_count_for_ems_id" do
    it "returns counts" do
      EvmSpecHelper.local_miq_server
      ems = FactoryGirl.create(:ems_vmware)
      storage = FactoryGirl.create(:storage)
      storage.scan_queue_item(1)
      storage.scan_queue_item(2)
      MiqQueue.update_all(:target_id => ems.id, :state => "dequeue")
      storage.scan_queue_item(3)

      expect(storage.smartstate_analysis_count_for_ems_id(ems.id)).to eq(2)
    end
  end

  context '#storage_clusters' do
    it 'returns only parents' do
      # A storage mounted on different VCs will have multiple parents
      storage          = FactoryGirl.create(:storage)
      storage_cluster1 = FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster1')
      storage_cluster2 = FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster2')
      _storage_cluster = FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster3')
      storage_cluster1.add_child(storage)
      storage_cluster2.add_child(storage)
      expect(storage.storage_clusters).to match_array([storage_cluster1, storage_cluster2])
    end

    it 'returns parents of type storage_cluster only' do
      # A storage mounted on different VCs will have multiple parents
      storage          = FactoryGirl.create(:storage)
      ems_folder       = FactoryGirl.create(:ems_folder,      :name => 'test_folder')
      storage_cluster1 = FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster1')
      storage_cluster2 = FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster2')
      ems_folder.add_child(storage)
      storage_cluster1.add_child(storage)
      storage_cluster2.add_child(storage)
      expect(storage.storage_clusters).to match_array([storage_cluster1, storage_cluster2])
      expect(storage.parents).to match_array([ems_folder, storage_cluster1, storage_cluster2])
    end

    it 'return [] if not in any storage cluster' do
      storage = FactoryGirl.create(:storage)
      expect(storage.storage_clusters).to match_array([])
    end
  end

  context "#tenant_identity" do
    let(:admin)    { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryGirl.create(:tenant) }
    let(:ems)      { FactoryGirl.create(:ext_management_system, :tenant => tenant) }
    let(:host)     { FactoryGirl.create(:host, :ext_management_system => ems) }

    before         { admin }
    it "has tenant from provider" do
      storage = FactoryGirl.create(:storage, :hosts => [host])

      expect(storage.tenant_identity).to                eq(admin)
      expect(storage.tenant_identity.current_group).to  eq(ems.tenant.default_miq_group)
      expect(storage.tenant_identity.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      storage = FactoryGirl.create(:storage)

      expect(storage.tenant_identity).to                eq(admin)
      expect(storage.tenant_identity.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(storage.tenant_identity.current_tenant).to eq(Tenant.root_tenant)
    end
  end
end
