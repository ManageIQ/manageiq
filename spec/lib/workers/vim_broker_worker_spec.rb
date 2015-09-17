require "spec_helper"

require 'MiqVim'
require 'MiqVimBroker'

describe MiqVimBrokerWorker::Runner do
  before(:each) do
    guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
    other_ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)

    # General stubbing for testing any worker (methods called during initialize)
    @worker_guid = MiqUUID.new_guid
    @worker_record = FactoryGirl.create(:miq_vim_broker_worker, :guid => @worker_guid, :miq_server_id => server.id)
    @drb_uri = "drb://127.0.0.1:12345"
    DRb.stub(:uri).and_return(@drb_uri)
    described_class.any_instance.stub(:sync_active_roles)
    described_class.any_instance.stub(:sync_config)
    described_class.any_instance.stub(:set_connection_pool_size)
    ManageIQ::Providers::Vmware::InfraManager.any_instance.stub(:authentication_check).and_return([true, ""])
    ManageIQ::Providers::Vmware::InfraManager.any_instance.stub(:authentication_status_ok?).and_return(true)
  end

  it "#after_initialize" do
    described_class.any_instance.should_receive(:start_broker_server).once
    described_class.any_instance.should_receive(:reset_broker_update_notification).once
    described_class.any_instance.should_receive(:reset_broker_update_sleep_interval).once
    vim_broker_worker = described_class.new({:guid => @worker_guid})

    vim_broker_worker.instance_variable_get(:@initial_emses_to_monitor).should match_array @zone.ext_management_systems

    @worker_record.reload
    @worker_record.uri.should == @drb_uri
    @worker_record.status.should == 'starting'
  end

  context "with a worker created" do
    before(:each) do
      described_class.any_instance.should_receive(:after_initialize).once
      @vim_broker_worker = described_class.new({:guid => @worker_guid})
    end

    context "#start_broker_server" do
      it "starts MiqVimBroker" do
        @vim_broker_worker.should_receive(:create_miq_vim_broker_server).once
        @vim_broker_worker.start_broker_server
      end

      it "does not prime when no EMSes specified" do
        @vim_broker_worker.stub(:create_miq_vim_broker_server)
        @vim_broker_worker.should_receive(:prime_all_ems).never
        @vim_broker_worker.start_broker_server
      end

      it "primes specified EMSes" do
        @vim_broker_worker.stub(:create_miq_vim_broker_server)
        emses_to_prime = @zone.ext_management_systems
        @vim_broker_worker.should_receive(:prime_all_ems).with(emses_to_prime).once
        @vim_broker_worker.start_broker_server(emses_to_prime)
      end

      it "should not raise error when MiqVimBroker.getMiqVim raises HTTPClient::ConnectTimeoutError" do
        require 'httpclient'  # needed for exception classes
        @miq_vim_broker = double('miq_vim_broker')
        MiqVimBroker.stub(:new).and_return(@miq_vim_broker)
        @miq_vim_broker.stub(:getMiqVim).and_raise(HTTPClient::ConnectTimeoutError)
        lambda { @vim_broker_worker.start_broker_server(@worker_record.class.emses_to_monitor) }.should_not raise_error
      end
    end

    it "#after_sync_config" do
      @vim_broker_worker.instance_variable_set(:@vim_broker_server, double('miq_vim_broker'))
      @vim_broker_worker.should_receive(:reset_broker_update_sleep_interval).once
      @vim_broker_worker.after_sync_config
    end

    context "#after_sync_active_roles" do
      it "on initialization" do
        MiqVimBroker.cacheScope = :cache_scope_core
        @vim_broker_worker.instance_variable_set(:@vim_broker_server, double('miq_vim_broker'))
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar'])

        lambda { @vim_broker_worker.after_sync_active_roles }.should_not raise_error
      end

      it "with role change not including 'ems_inventory' role" do
        MiqVimBroker.cacheScope = :cache_scope_core
        @vim_broker_worker.instance_variable_set(:@vim_broker_server, double('miq_vim_broker'))
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar'])

        lambda { @vim_broker_worker.after_sync_active_roles }.should_not raise_error
      end

      it "adding 'ems_inventory' role" do
        MiqVimBroker.cacheScope = :cache_scope_core
        @vim_broker_worker.instance_variable_set(:@vim_broker_server, double('miq_vim_broker'))
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar', 'ems_inventory'])

        lambda { @vim_broker_worker.after_sync_active_roles }.should raise_error(SystemExit)
      end

      it "removing 'ems_inventory' role" do
        MiqVimBroker.cacheScope = :cache_scope_ems_refresh
        @vim_broker_worker.instance_variable_set(:@vim_broker_server, double('miq_vim_broker'))
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar'])

        lambda { @vim_broker_worker.after_sync_active_roles }.should raise_error(SystemExit)
      end
    end

    it "#do_heartbeat_work" do
      @vim_broker_worker.should_receive(:check_broker_server).once
      @vim_broker_worker.should_receive(:log_status).once
      @vim_broker_worker.do_heartbeat_work
    end

    context "#do_before_work_loop" do
      it "should do nothing when active roles does not include 'ems_inventory'" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar'])
        EmsRefresh.should_receive(:queue_refresh).never
        @vim_broker_worker.do_before_work_loop
      end

      it "should do nothing when active roles includes 'ems_inventory' and there are no EMSes to monitor" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar', 'ems_inventory'])
        @vim_broker_worker.instance_variable_set(:@initial_emses_to_monitor, [])
        EmsRefresh.should_receive(:queue_refresh).never
        @vim_broker_worker.do_before_work_loop
      end

      it "should call EmsRefresh.queue_refresh when active roles includes 'ems_inventory' and there are EMSes to monitor" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar', 'ems_inventory'])
        emses = @zone.ext_management_systems
        @vim_broker_worker.instance_variable_set(:@initial_emses_to_monitor, emses)
        EmsRefresh.should_receive(:queue_refresh).with(emses).once
        @vim_broker_worker.do_before_work_loop
      end

    end

    context "#create_miq_vim_broker_server" do
      it "with ems_inventory role" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['ems_inventory'])
        MiqVimBroker.should_receive(:new).with(:server, 0).once
        @vim_broker_worker.create_miq_vim_broker_server
        MiqVimBroker.cacheScope.should == :cache_scope_ems_refresh
      end

      it "without ems_inventory role" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['ems_operations'])
        MiqVimBroker.should_receive(:new).with(:server, 0).once
        @vim_broker_worker.create_miq_vim_broker_server
        MiqVimBroker.cacheScope.should == :cache_scope_core
      end
    end

    it "#prime_all_ems" do
      emses = @zone.ext_management_systems
      emses.each { |ems| @vim_broker_worker.should_receive(:prime_ems).with(ems).once }
      @vim_broker_worker.prime_all_ems(emses)
    end

    it "#prime_ems" do
      @vim_broker_worker.should_receive(:preload).with(@ems).once
      @vim_broker_worker.prime_ems(@ems)
    end

    it "#reconnect_ems" do
      @vim_broker_worker.should_receive(:preload).with(@ems).once
      EmsRefresh.should_receive(:queue_refresh).with(@ems).once
      @vim_broker_worker.reconnect_ems(@ems)
    end

    it "#preload" do
      @miq_vim_broker = double('miq_vim_broker')
      @vim_handle     = double('vim_handle')
      @vim_broker_worker.instance_variable_set(:@vim_broker_server, @miq_vim_broker)
      @miq_vim_broker.should_receive(:getMiqVim).once.with(@ems.address, *@ems.auth_user_pwd).and_return(@vim_handle)
      @vim_handle.should_receive(:disconnect).once
      @vim_broker_worker.preload(@ems)
    end

    context "#reset_broker_update_notification" do
      it "calls enable_broker_update_notification when active roles includes 'ems_inventory'" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['ems_inventory'])
        @vim_broker_worker.should_receive(:enable_broker_update_notification).once
        @vim_broker_worker.should_receive(:disable_broker_update_notification).never
        @vim_broker_worker.reset_broker_update_notification
      end

      it "calls disable_broker_update_notification when active roles does not include 'ems_inventory'" do
        @vim_broker_worker.instance_variable_set(:@active_roles, ['foo', 'bar'])
        @vim_broker_worker.should_receive(:enable_broker_update_notification).never
        @vim_broker_worker.should_receive(:disable_broker_update_notification).once
        @vim_broker_worker.reset_broker_update_notification
      end
    end

    context "#drain_event" do
      context "instance with update notification enabled" do
        before(:each) do
          @vim_broker_worker.instance_variable_set(:@vim_broker_server, double('dummy_broker_server').as_null_object)
          @vim_broker_worker.instance_variable_set(:@active_roles, ['ems_inventory'])
          @vim_broker_worker.instance_variable_set(:@queue, Queue.new)
          @vim_broker_worker.enable_broker_update_notification
        end

        it "will handle queued Vm updates properly" do
          vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
          event = {
            :server       => @ems.address,
            :username     => @ems.authentication_userid,
            :objType      => "VirtualMachine",
            :op           => "update",
            :mor          => vm.ems_ref_obj,
            :key          => "testkey",
            :changedProps => ["summary.runtime.powerState"],
            :changeSet    => [{"name" => "summary.runtime.powerState", "op" => "assign", "val" => "poweredOn"}]
          }
          @vim_broker_worker.instance_variable_get(:@queue).enq(event.dup)

          @vim_broker_worker.drain_event
          MiqQueue.count.should == 1
          q = MiqQueue.first
          q.class_name.should  == "EmsRefresh"
          q.method_name.should == "vc_update"
          q.args.should        == [@ems.id, event]
        end

        it "will handle queued Host updates properly" do
          host = FactoryGirl.create(:host_with_ref, :ext_management_system => @ems)
          event = {
            :server       => @ems.address,
            :username     => @ems.authentication_userid,
            :objType      => "HostSystem",
            :op           => "update",
            :mor          => host.ems_ref_obj,
            :key          => "testkey",
            :changedProps => ["summary.runtime.connectionState"],
            :changeSet    => [{"name" => "summary.runtime.connectionState", "op" => "assign", "val" => "connected"}]
          }
          @vim_broker_worker.instance_variable_get(:@queue).enq(event.dup)

          @vim_broker_worker.drain_event
          MiqQueue.count.should == 1
          q = MiqQueue.first
          q.class_name.should  == "EmsRefresh"
          q.method_name.should == "vc_update"
          q.args.should        == [@ems.id, event]
        end

        it "will ignore updates to unknown properties" do
          vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
          @vim_broker_worker.instance_variable_get(:@queue).enq({
            :server       => @ems.address,
            :username     => @ems.authentication_userid,
            :objType      => "VirtualMachine",
            :op           => "update",
            :mor          => vm.ems_ref_obj,
            :key          => "testkey",
            :changedProps => ["test.property"],
            :changeSet    => [{"name" => "test.property", "op" => "assign", "val" => "test"}]
          })

          @vim_broker_worker.drain_event
          MiqQueue.count.should == 0
        end

        it "will ignore updates to excluded properties" do
          @vim_broker_worker.instance_variable_set(:@exclude_props, {"VirtualMachine" => {"summary.runtime.powerState" => nil}})

          vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
          @vim_broker_worker.instance_variable_get(:@queue).enq({
            :server       => @ems.address,
            :username     => @ems.authentication_userid,
            :objType      => "VirtualMachine",
            :op           => "update",
            :mor          => vm.ems_ref_obj,
            :key          => "testkey",
            :changedProps => ["summary.runtime.powerState"],
            :changeSet    => [{"name" => "summary.runtime.powerState", "op" => "assign", "val" => "poweredOn"}]
          })

          @vim_broker_worker.drain_event
          MiqQueue.count.should == 0
        end

        it "will ignore updates to unknown connections" do
          vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
          @vim_broker_worker.instance_variable_get(:@queue).enq({
            :server       => "XXX.XXX.XXX.XXX",
            :username     => "someuser",
            :objType      => "VirtualMachine",
            :op           => "update",
            :mor          => vm.ems_ref_obj,
            :key          => "testkey",
            :changedProps => ["summary.runtime.powerState"],
            :changeSet    => [{"name" => "summary.runtime.powerState", "op" => "assign", "val" => "poweredOn"}]
          })

          @vim_broker_worker.drain_event
          MiqQueue.count.should == 0
        end

        it "will handle updates to valid connections that it previously did not know about" do
          ems2 = FactoryGirl.create(:ems_vmware_with_authentication, :zone_id => @zone.id)
          vm2  = FactoryGirl.create(:vm_with_ref, :ext_management_system => ems2)

          event = {
            :server       => ems2.address,
            :username     => ems2.authentication_userid,
            :objType      => "VirtualMachine",
            :op           => "update",
            :mor          => vm2.ems_ref_obj,
            :key          => "testkey",
            :changedProps => ["summary.runtime.powerState"],
            :changeSet    => [{"name" => "summary.runtime.powerState", "op" => "assign", "val" => "poweredOn"}]
          }
          @vim_broker_worker.instance_variable_get(:@queue).enq(event.dup)

          @vim_broker_worker.drain_event
          MiqQueue.count.should == 1
          q = MiqQueue.first
          q.class_name.should  == "EmsRefresh"
          q.method_name.should == "vc_update"
          q.args.should        == [ems2.id, event]
        end
      end
    end
  end
end
