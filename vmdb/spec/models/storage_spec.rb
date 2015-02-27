require "spec_helper"

describe Storage do
  it "#scan_watchdog_interval" do
    Storage.stub(:vmdb_storage_config => {})
    Storage.scan_watchdog_interval.should == Storage::DEFAULT_WATCHDOG_INTERVAL

    Storage.stub(:vmdb_storage_config => {'watchdog_interval' => '5.minutes'})
    Storage.scan_watchdog_interval.should == 5.minutes
  end

  it "#max_parallel_storage_scans_per_host" do
    Storage.stub(:vmdb_storage_config => {})
    Storage.max_parallel_storage_scans_per_host.should == Storage::DEFAULT_MAX_PARALLEL_SCANS_PER_HOST

    Storage.stub(:vmdb_storage_config => {'max_parallel_scans_per_host' => 3})
    Storage.max_parallel_storage_scans_per_host.should == 3
  end

  it "#max_qitems_per_scan_request" do
    Storage.stub(:vmdb_storage_config => {})
    Storage.max_qitems_per_scan_request.should == Storage::DEFAULT_MAX_QITEMS_PER_SCAN_REQUEST

    Storage.stub(:vmdb_storage_config => {'max_qitems_per_scan_request' => 3})
    Storage.max_qitems_per_scan_request.should == 3
  end

  it "#scan_collection_timeout" do
    Storage.stub(:vmdb_storage_config => {})
    Storage.scan_collection_timeout.should be_nil

    Storage.stub(:vmdb_storage_config => { :collection => {:timeout => 3} } )
    Storage.scan_collection_timeout.should == 3
  end

  it "#scan_watchdog_deliver_on" do
    scan_watchdog_interval = 7.minutes
    Storage.stub(:scan_watchdog_interval => scan_watchdog_interval)
    start = Time.parse("Sun March 10 01:00:00 UTC 2010")
    Timecop.travel(start) do
      (Storage.scan_watchdog_deliver_on - (start + scan_watchdog_interval)).should be_within(0.001).of(0.0)
    end
  end

  it "#vmdb_storage_config" do
    config = { :foo => 1, :bar => 2 }
    vmdb_storage_config = double('vmdb_storage_config')
    vmdb_storage_config.stub(:config => config)
    VMDB::Config.stub(:new).with('storage').and_return(vmdb_storage_config)
    Storage.vmdb_storage_config.should == config
  end

  it "#scan_complete?" do
    miq_task = FactoryGirl.create(:miq_task)
    miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
    miq_task.context_data[:targets]  = [123, 456, 789]
    miq_task.context_data[:complete] = []
    Storage.scan_complete?(miq_task).should be_false

    miq_task.context_data[:complete]  = [123, 456, 789]
    Storage.scan_complete?(miq_task).should be_true
  end

  it "#scan_complete_message" do
    miq_task = FactoryGirl.create(:miq_task)
    miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
    miq_task.context_data[:targets]  = [123, 456, 789]
    Storage.scan_complete_message(miq_task).should == "SmartState Analysis for 3 storages complete"
  end

  it "#scan_update_message" do
    miq_task = FactoryGirl.create(:miq_task)
    miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
    miq_task.context_data[:targets]  = [123, 456, 789]
    miq_task.context_data[:complete] = [123]
    miq_task.context_data[:pending][789] = 98765
    Storage.scan_update_message(miq_task).should == "1 Storage Scans Pending; 1 of 3 Scans Complete"
  end

  context "with multiple storages" do
    before(:each) do
      @guid   = MiqUUID.new_guid
      @zone   = FactoryGirl.create(:zone)
      @server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid)
      MiqServer.stub(:my_guid => @guid)
      MiqServer.my_server(true)

      @zone2     = FactoryGirl.create(:zone, :name => 'Bedrock')
      @ems1      = FactoryGirl.create(:ems_vmware, :name => "test_vcenter1",     :zone => @zone)
      @ems2      = FactoryGirl.create(:ems_vmware, :name => "test_vcenter2",     :zone => @zone2)
      @storage1  = FactoryGirl.create(:storage,               :name => "test_storage_vmfs", :store_type => "VMFS")
      @storage2  = FactoryGirl.create(:storage,               :name => "test_storage_nfs",  :store_type => "NFS")
      @storage3  = FactoryGirl.create(:storage,               :name => "test_storage_foo",  :store_type => "FOO")
      @host1     = FactoryGirl.create(:host, :name => "test_host1", :hostname => "test_host1", :state => 'on', :ems_id => @ems1.id, :storages => [@storage1, @storage3])
      @host2     = FactoryGirl.create(:host, :name => "test_host2", :hostname => "test_host2", :state => 'on', :ems_id => @ems2.id, :storages => [@storage2, @storage3])
    end

    it "#active_hosts_in_zone" do
      @storage1.active_hosts_in_zone(@zone.name).should  == [@host1]
      @storage1.active_hosts_in_zone(@zone2.name).should == []
      @storage2.active_hosts_in_zone(@zone.name).should  == []
      @storage2.active_hosts_in_zone(@zone2.name).should == [@host2]
      @storage3.active_hosts_in_zone(@zone.name).should  == [@host1]
      @storage3.active_hosts_in_zone(@zone2.name).should == [@host2]
    end

    it "#active_hosts" do
      @storage1.active_hosts.should == [@host1]
      @storage2.active_hosts.should == [@host2]
      @storage3.active_hosts.should match_array [@host1, @host2]
    end

    it "#my_zone" do
      @storage1.my_zone.should == @zone.name
      @storage2.my_zone.should == @zone2.name
      @storage3.my_zone.should == @zone.name
    end

    it "#scan_queue_item" do
      scan_collection_timeout = 456
      Storage.stub(:scan_collection_timeout => scan_collection_timeout)

      miq_task = FactoryGirl.create(:miq_task)
      qitem = @storage1.scan_queue_item(miq_task.id)

      qitem.class_name.should   == @storage1.class.name
      qitem.instance_id.should  == @storage1.id
      qitem.method_name.should  == 'smartstate_analysis'
      qitem.args.should         == [miq_task.id]
      qitem.msg_timeout.should  == scan_collection_timeout
      qitem.zone.should         == @storage1.my_zone
      qitem.role.should         == 'ems_operations'
      qitem.miq_callback.should == { :class_name => @storage1.class.name, :instance_id => @storage1.id, :method_name => :scan_complete_callback, :args => [miq_task.id] }
    end

    it "#scan_storages_unprocessed" do
      miq_task = FactoryGirl.create(:miq_task)
      miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
      miq_task.context_data[:targets]  = [@storage1.id, @storage2.id, @storage3.id]
      miq_task.context_data[:complete] = []
      miq_task.context_data[:pending]  = {}
      Storage.scan_storages_unprocessed(miq_task).should match_array [@storage1.id, @storage2.id, @storage3.id]

      miq_task.context_data[:complete] = [@storage3.id]
      Storage.scan_storages_unprocessed(miq_task).should match_array [@storage1.id, @storage2.id]

      miq_task.context_data[:pending][@storage2.id] = 12345
      Storage.scan_storages_unprocessed(miq_task).should == [@storage1.id]

      miq_task.context_data[:pending].delete(@storage2.id)
      Storage.scan_storages_unprocessed(miq_task).should match_array [@storage1.id, @storage2.id]

      miq_task.context_data[:complete]  = [@storage1.id, @storage2.id, @storage3.id]
      Storage.scan_storages_unprocessed(miq_task).should == []
    end

    it "#scan_queue_watchdog" do
      miq_task = FactoryGirl.create(:miq_task)
      deliver_on = Time.now.utc + 1.hour
      Storage.stub(:scan_watchdog_deliver_on => deliver_on)
      watchdog = Storage.scan_queue_watchdog(miq_task.id)
      watchdog.class_name.should  == 'Storage'
      watchdog.method_name.should == 'scan_watchdog'
      watchdog.args.should        == [miq_task.id]
      watchdog.zone.should        == MiqServer.my_zone
      watchdog.deliver_on.should  == deliver_on
    end

    context "on a host without credentials" do
      it "#scan will raise error" do
        lambda { @storage1.scan }.should raise_error(MiqException::MiqStorageError)
      end
    end

    context "on a host authentication status ok" do
      before(:each) do
        Authentication.any_instance.stub(:after_authentication_changed)
        FactoryGirl.create(:authentication, :resource => @host1, :status => "Valid")
      end

      it "#ext_management_systems" do
        @storage1.ext_management_systems.should == [@ems1]
        @storage2.ext_management_systems.should == [@ems2]
        @storage3.ext_management_systems.should match_array [@ems1, @ems2]
      end

      it "#ext_management_systems_in_zone" do
        @storage1.ext_management_systems_in_zone(@zone.name).should  == [@ems1]
        @storage1.ext_management_systems_in_zone(@zone2.name).should == []
        @storage2.ext_management_systems_in_zone(@zone.name).should  == []
        @storage2.ext_management_systems_in_zone(@zone2.name).should == [@ems2]
        @storage3.ext_management_systems_in_zone(@zone.name).should  == [@ems1]
        @storage3.ext_management_systems_in_zone(@zone2.name).should == [@ems2]
      end

      it "#active_hosts_with_authentication_status_ok" do
        @storage1.active_hosts_with_authentication_status_ok.should == [@host1]
        @storage2.active_hosts_with_authentication_status_ok.should == []
        @storage3.active_hosts_with_authentication_status_ok.should == [@host1]
      end

      it "#active_hosts_with_authentication_status_ok_in_zone" do
        @storage1.active_hosts_with_authentication_status_ok_in_zone(@zone.name).should  == [@host1]
        @storage1.active_hosts_with_authentication_status_ok_in_zone(@zone2.name).should == []
        @storage2.active_hosts_with_authentication_status_ok_in_zone(@zone.name).should  == []
        @storage2.active_hosts_with_authentication_status_ok_in_zone(@zone2.name).should == []
        @storage3.active_hosts_with_authentication_status_ok_in_zone(@zone.name).should  == [@host1]
        @storage3.active_hosts_with_authentication_status_ok_in_zone(@zone2.name).should == []
      end

      it "#scan" do
        lambda { @storage3.scan }.should raise_error(MiqException::MiqUnsupportedStorage)

        MiqEvent.should_receive(:raise_evm_job_event).once
        @storage1.scan

        task = MiqTask.find(:first)
        task.userid.should == "system"
        task.name.should == "SmartState Analysis for [#{@storage1.name}]"

        message = MiqQueue.find(:first, :conditions => { :method_name => "smartstate_analysis"})
        message.instance_id.should == @storage1.id
        message.args.should == [task.id]
        message.zone.should == @zone.name
        message.role.should == "ems_operations"
      end

      context "with performance capture disabled" do
        before(:each) do
          Storage.any_instance.stub(:perf_capture_enabled? => false)
        end

        it "#scan_eligible_storages" do
          Storage.scan_eligible_storages.should              be_empty
          Storage.scan_eligible_storages(nil).should         be_empty
          Storage.scan_eligible_storages(@zone.name).should  be_empty
          Storage.scan_eligible_storages(@zone2.name).should be_empty
        end

        it "#scan_timer" do
          Storage.should_receive(:scan_queue_watchdog).never
          miq_task  = Storage.scan_timer(nil)
          miq_task.should be_nil
          MiqTask.count.should  == 0
          MiqQueue.count.should == 0
        end

      end

      context "with performance capture enabled" do
        before(:each) do
          Storage.any_instance.stub(:perf_capture_enabled? => true)
          MiqEvent.stub(:raise_evm_job_event)
        end

        it "#scan_eligible_storages" do
          Storage.scan_eligible_storages.should              match_array [@storage1, @storage2]
          Storage.scan_eligible_storages(nil).should         match_array [@storage1, @storage2]
          Storage.scan_eligible_storages(@zone.name).should  == [@storage1]
          Storage.scan_eligible_storages(@zone2.name).should == [@storage2]
        end

        it "#scan_queue" do
          Storage.stub(:max_parallel_storage_scans => 1)
          bogus_id = @storage1.id - 1
          miq_task = FactoryGirl.create(:miq_task)
          miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
          miq_task.context_data[:targets]  = [bogus_id, @storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete] = []
          miq_task.context_data[:pending]  = {}
          miq_task.save!

          qitem1  = FactoryGirl.create(:miq_queue)
          Storage.any_instance.stub(:scan_queue_item => qitem1)
          Storage.scan_queue(miq_task)
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == []
          miq_task.context_data[:pending].length.should == 1
          miq_task.context_data[:pending][@storage1.id].should == qitem1.id

          miq_task.context_data[:complete] << @storage1.id
          miq_task.context_data[:pending].delete(@storage1.id)
          miq_task.save!
          qitem2  = FactoryGirl.create(:miq_queue)
          Storage.any_instance.stub(:scan_queue_item => qitem2)
          Storage.scan_queue(miq_task)
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == [@storage1.id]
          miq_task.context_data[:pending].length.should == 1
          miq_task.context_data[:pending][@storage2.id].should == qitem2.id

          miq_task.context_data[:complete] << @storage2.id
          miq_task.context_data[:pending].delete(@storage2.id)
          miq_task.save!
          Storage.any_instance.stub(:scan_queue_item).and_raise(MiqException::MiqUnsupportedStorage)
          Storage.scan_queue(miq_task)
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id]
          miq_task.context_data[:complete].should       == [@storage1.id, @storage2.id]
          miq_task.context_data[:pending].length.should == 0
        end

        it "#scan_watchdog" do
          max_qitems_per_scan_request = 1
          Storage.stub(:max_qitems_per_scan_request => max_qitems_per_scan_request)
          miq_task = FactoryGirl.create(:miq_task)
          miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
          miq_task.context_data[:targets]  = [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete] = []
          miq_task.context_data[:pending]  = {}
          miq_task.save!

          Storage.should_receive(:scan_queue_watchdog).with(miq_task.id).once
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == []
          miq_task.context_data[:pending].length.should == 0

          qitem1  = FactoryGirl.create(:miq_queue)
          miq_task.context_data[:pending][@storage1.id] = qitem1.id
          miq_task.save!
          Storage.should_receive(:scan_queue_watchdog).with(miq_task.id).once
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          miq_task.context_data[:targets].should               == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should              == []
          miq_task.context_data[:pending].length.should        == 1
          miq_task.context_data[:pending][@storage1.id].should == qitem1.id

          qitem1.destroy
          Storage.should_receive(:scan_queue).with(miq_task).once
          Storage.should_receive(:scan_queue_watchdog).with(miq_task.id).once
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == []
          miq_task.context_data[:pending].length.should == 0

          miq_task.context_data[:complete] = [@storage1.id, @storage2.id, @storage3.id]
          miq_task.save!
          Storage.should_receive(:scan_queue).never
          Storage.should_receive(:scan_queue_watchdog).never
          Storage.scan_watchdog(miq_task.id)
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:pending].length.should == 0
        end

        it "#scan_complete_callback" do
          miq_task = FactoryGirl.create(:miq_task)
          miq_task.context_data = { :targets => [], :complete => [], :pending  => {} }
          miq_task.context_data[:targets]  = [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete] = []
          miq_task.context_data[:pending][@storage1.id] = 123
          miq_task.save!
          Storage.should_receive(:scan_queue).with(miq_task).once
          @storage1.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == [@storage1.id]
          miq_task.context_data[:pending].length.should == 0
          miq_task.pct_complete.should                  == 33

          miq_task.context_data[:pending][@storage2.id] = 456
          miq_task.save!
          Storage.should_receive(:scan_queue).with(miq_task).once
          @storage2.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == [@storage1.id, @storage2.id]
          miq_task.context_data[:pending].length.should == 0
          miq_task.pct_complete.should                  == 66

          miq_task.context_data[:pending][@storage3.id] = 789
          miq_task.save!
          Storage.should_receive(:scan_queue).never
          MiqTask.any_instance.should_receive(:update_status).once
          @storage3.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
          miq_task.reload
          miq_task.context_data[:targets].should        == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:complete].should       == [@storage1.id, @storage2.id, @storage3.id]
          miq_task.context_data[:pending].length.should == 0
          miq_task.pct_complete.should                  == 100

          miq_task.destroy
          Storage.should_receive(:scan_queue).never
          MiqTask.any_instance.should_receive(:update_status).never
          @storage1.scan_complete_callback(miq_task.id, 'status', 'message', 'result')
        end

        it "#scan_timer" do
          Storage.should_receive(:scan_queue_watchdog).once
          Storage.stub(:scan_queue)
          miq_task  = Storage.scan_timer(nil)
          miq_tasks = MiqTask.all
          miq_tasks.length.should == 1
          miq_task.should         == miq_tasks.first
          miq_task.should_not be_nil
          miq_task.userid.should  == "system"
          miq_task.name.should    == "SmartState Analysis for All Storages"
          miq_task.state.should   == MiqTask::STATE_QUEUED
          cdata = miq_task.context_data
          cdata[:targets].should  match_array Storage.scan_eligible_storages.collect(&:id)
          cdata[:complete].should be_empty
          cdata[:pending].should  be_empty
        end

        it "#scan_timer(zone)" do
          miq_task = Storage.scan_timer(@zone.name)
          miq_task.name.should == "SmartState Analysis for All Storages in Zone \"#{@zone.name}\""
          miq_task.context_data[:targets].should match_array Storage.scan_eligible_storages(@zone.name).collect(&:id)
        end

      end
    end
  end
end
