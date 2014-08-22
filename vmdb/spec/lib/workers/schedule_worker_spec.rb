require "spec_helper"

require 'workers/schedule_worker'

describe ScheduleWorker do
  context ".new" do
    before(:each) do
      @server_guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@server_guid)
      @zone       = FactoryGirl.create(:zone)
      @miq_server = FactoryGirl.create(:miq_server_master, :zone => @zone, :guid => @server_guid)
      MiqServer.my_server(true)

      @worker_guid = MiqUUID.new_guid
      @worker = FactoryGirl.create(:miq_schedule_worker, :guid => @worker_guid, :miq_server_id => @miq_server.id)

      ScheduleWorker.any_instance.stub(:initialize_rufus)
      ScheduleWorker.any_instance.stub(:sync_active_roles)
      ScheduleWorker.any_instance.stub(:sync_config)
      ScheduleWorker.any_instance.stub(:set_connection_pool_size)

      @schedule_worker = ScheduleWorker.new(:guid => @worker_guid)
    end

    context "with a stuck dispatch in each zone" do
      before(:each) do
        @cond = {:class_name => 'JobProxyDispatcher', :method_name => 'dispatch'}
        @opts = @cond.merge({:state => 'dequeue', :updated_on => Time.now.utc })
        @stale_timeout = 2.minutes
        @schedule_worker.stub(:worker_settings).and_return({:job_proxy_dispatcher_stale_message_timeout => @stale_timeout} )

        @zone1 = @zone
        @worker1 = FactoryGirl.create(:miq_worker, :status => MiqWorker::STATUS_STOPPED)
        @dispatch1 = FactoryGirl.create(:miq_queue, {:zone => @zone1.name, :handler_type => @worker1.class.name, :handler_id => @worker1.id}.merge(@opts))

        @zone2 = FactoryGirl.create(:zone, :name => 'zone2')
        @worker2 = FactoryGirl.create(:miq_worker, :status => MiqWorker::STATUS_STOPPED)

        MiqServer.stub(:my_zone).and_return(@zone1.name)
        Timecop.travel 5.minutes
      end

      after(:each) do
        Timecop.return
      end

      it "check_for_dispatch calls check_for_timeout which deletes both dispatches" do
        @dispatch2 = FactoryGirl.create(:miq_queue, {:zone => @zone2.name, :handler_type => @worker2.class.name, :handler_id => @worker2.id}.merge(@opts))

        MiqQueue.count(:conditions => @cond).should == 2
        ScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
        MiqQueue.count(:conditions => @cond).should == 0
      end

      it "check_for_dispatch calls check_for_timeout with triple threshold for active worker" do
        @worker1.update_attribute(:status, MiqWorker::STATUS_STARTED)
        MiqQueue.any_instance.should_receive(:check_for_timeout).once do |prefix, grace, timeout|
          timeout.should == @stale_timeout * 3
        end
        ScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
      end

      it "check_for_dispatch calls check_for_timeout with threshold for inactive worker" do
        MiqQueue.any_instance.should_receive(:check_for_timeout).once do |prefix, grace, timeout|
            timeout.should == @stale_timeout
        end
        ScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
      end

      it "check_for_dispatch calls check_for_timeout which deletes for in-active worker" do
        @dispatch2 = FactoryGirl.create(:miq_queue, {:zone => @zone2.name, :handler_type => @worker2.class.name, :handler_id => @worker2.id}.merge(@opts))

        @worker1.update_attribute(:status, MiqWorker::STATUS_STARTED)
        cond_active = @cond.dup
        cond_active[:handler_id] = @worker1.id
        MiqQueue.count(:conditions => @cond).should == 2
        ScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
        MiqQueue.count(:conditions => @cond).should == 1
        MiqQueue.count(:conditions => cond_active).should == 1
      end
    end

    context "with Time before DST" do
      before(:each) do
        @start = Time.parse('Sun November 6 01:00:00 -0400 2010')
        @east_tz = 'Eastern Time (US & Canada)'
        Timecop.travel(@start)
        @schedule_worker.reset_dst
      end

      after(:each) do
        Timecop.return
      end

      context "using Rufus::Scheduler" do
        before(:each) do
          rufus_frequency = 0.00001  # How often rufus will check for jobs to do
          require 'rufus/scheduler'
          @schedule_worker.instance_eval do
            @system_scheduler = Rufus::Scheduler.start_new(:frequency => rufus_frequency)
            @user_scheduler   = Rufus::Scheduler.start_new(:frequency => rufus_frequency)
          end
          @user = @schedule_worker.instance_variable_get(:@user_scheduler)
          @system = @schedule_worker.instance_variable_get(:@system_scheduler)
        end

        after(:each) do
          @user.stop
          @system.stop
          @user = nil
          @system = nil
        end

        it "monthly schedule scheduled for 5 years will be unscheduled by tag" do
          first_at = Time.utc(2011, 1, 1, 8, 30)
          tag = "miq_schedules_1"
          @sch = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2011-01-01 08:30:00 Z", :interval => { :unit => "monthly", :value => "1" }})
          @schedule_worker.rufus_add_schedule(:method => :schedule_at, :interval => first_at, :months => 1, :schedule_id => @sch.id, :discard_past => true, :tags => tag)
          @schedule_worker.queue_length.should == 0

          @schedule_worker.rufus_remove_schedules_by_tag(tag)

          @user.find_by_tag(tag).should be_empty
        end

        it "monthly creates a schedule each month for 5 years" do
          first_at = Time.utc(2011, 1, 1, 8, 30)
          @sch = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2011-01-01 08:30:00 Z", :interval => { :unit => "monthly", :value => "1" }})

          Timecop.freeze(first_at - 1.minute) do
            @schedule_worker.rufus_add_schedule(:method => :schedule_at, :interval => first_at, :months => 1, :schedule_id => @sch.id, :discard_past => true, :tags => "miq_schedules_1")
            schedules = @schedule_worker.instance_variable_get(:@schedules)
            schedules[:scheduler].length.should == 60
          end
        end

        it "monthly schedule starting Jan 31 will next run Feb 28" do
          first_at = Time.utc(2011, 1, 31, 8, 30)
          @sch = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2011-01-31 08:30:00 Z", :interval => { :unit => "monthly", :value => "1" }})

          Timecop.freeze(first_at + 1.minute) do
            schedules = @schedule_worker.rufus_add_schedule(:method => :schedule_at, :interval => first_at, :months => 1, :schedule_id => @sch.id, :discard_past => true, :tags => "miq_schedules_1")

            job = @user.find_by_tag("miq_schedules_1").first
            job.next_time.should == Time.utc(2011, 2, 28, 8, 30, 0)
          end
        end

        context "#system_schedule_every" do
          it "catches an error on nil first arg" do
            $log.should_receive(:error).once
            @schedule_worker.system_schedule_every(nil) {}
          end

          it "catches an error on 0 first arg" do
            $log.should_receive(:error).once
            @schedule_worker.system_schedule_every(0) {}
          end

          it "works on nil :first_in" do
            $log.should_receive(:error).never
            @schedule_worker.system_schedule_every(1, :first_in => nil) {}
          end
        end

        context "calling check_roles_changed" do
          before(:each) do
            # ScheduleWorker.any_instance.stub(:schedules_for_scheduler_role)
            @schedule_worker.stub(:worker_settings).and_return(Hash.new(5.minutes))
            @schedule_worker.instance_variable_set(:@schedules, {:scheduler => []})

            @sch1 = FactoryGirl.create(:miq_schedule)
            @sch2 = FactoryGirl.create(:miq_schedule)
          end

          it "should load all user schedules when scheduler role is added" do
            @schedule_worker.instance_variable_set(:@active_roles,  ["scheduler"])
            @schedule_worker.instance_variable_set(:@current_roles, [])

            @user.jobs.length.should == 0

            @schedule_worker.schedules_for_scheduler_role
            @system.jobs.length.should > 0

            @schedule_worker.check_roles_changed
            @user.jobs.length.should == 2
          end

          it "should unload all user schedules when scheduler role is removed" do
            # start with with scheduler role
            @schedule_worker.instance_variable_set(:@active_roles,  ["scheduler"])
            @schedule_worker.instance_variable_set(:@current_roles, [])

            @schedule_worker.schedules_for_scheduler_role
            @system.jobs.length.should > 0

            @schedule_worker.sync_all_user_schedules
            @user.jobs.length.should == 2

            # Make sure only real schedules are processed
            schedules = @schedule_worker.instance_variable_get(:@schedules)
            schedules[:scheduler] << nil
            @schedule_worker.instance_variable_set(:@schedules, schedules)

            # remove scheduler role
            @schedule_worker.instance_variable_set(:@active_roles,  [])
            @schedule_worker.instance_variable_set(:@current_roles, ["scheduler"])
            @schedule_worker.check_roles_changed

            @system.jobs.length.should == 0
            @user.jobs.length.should == 0
          end
        end

        context "nil worker_settings values" do
          before do
            @schedule_worker.stub(:worker_settings).and_return({})
            $log.should_receive(:error).never
          end

          it "#schedules_for_all_roles" do
            @schedule_worker.schedules_for_all_roles
          end

          it "#schedules_for_scheduler_role" do
            @schedule_worker.instance_variable_set(:@active_roles, ['scheduler'])
            @schedule_worker.schedules_for_scheduler_role
          end

          it "#schedules_for_event_role" do
            @schedule_worker.instance_variable_set(:@active_roles, ['event'])
            @schedule_worker.schedules_for_event_role
          end

          it "#schedules_for_ems_metrics_coordinator_role" do
            @schedule_worker.instance_variable_set(:@active_roles, ['ems_metrics_coordinator'])
            @schedule_worker.schedules_for_ems_metrics_coordinator_role
          end

          it "#schedules_for_ldap_synchronization_role" do
            @schedule_worker.instance_variable_set(:@active_roles, ['ldap_synchronization'])
            @schedule_worker.schedules_for_ldap_synchronization_role
          end
        end

        context "LDAP synchronization role" do
          before(:each) do
            VMDB::Config.any_instance.stub(:config).and_return(Hash.new(5.minutes))
            @schedule_worker.stub(:heartbeat)

            # Initialize active_roles
            @schedule_worker.instance_variable_set(:@active_roles, [])

            MiqRegion.seed
            @region = MiqRegion.my_region
            MiqRegion.stub(:my_region).and_return(@region)
            @schedule_worker.instance_variable_set(:@active_roles, ["ldap_synchronization"])

            @ldap_synchronization_collection = { :ldap_synchronization_schedule => "0 2 * * *" }
            config                           = { :ldap_synchronization => @ldap_synchronization_collection }

            vmdb_config = double("vmdb_config")
            vmdb_config.stub(:config => config)
            vmdb_config.stub(:merge_from_template_if_missing)
            VMDB::Config.stub(:new).with("vmdb").and_return(vmdb_config)
          end

          context "#schedules_for_ldap_synchronization_role" do
            before(:each) do
              @region.stub(:role_active?).with("ldap_synchronization").and_return(true)
            end

            it "queues the right items" do
              scheduled_jobs = @schedule_worker.schedules_for_ldap_synchronization_role

              scheduled_jobs.each do |job|
                case job.tags
                when [:ldap_synchronization, :ldap_synchronization_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @ldap_synchronization_collection[:ldap_synchronization_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 1
                  message = MiqQueue.where(:class_name  => "LdapServer", :method_name => "sync_data_from_timer").first
                  message.should_not be_nil

                  MiqQueue.delete_all
                else
                  raise "Unexpected Job: tags=#{job.tags.inspect}, t=#{job.t.inspect}, last=#{job.last.inspect}, id=#{job.job_id.inspect}, thr=#{job.last_job_thread.inspect}, next=#{job.next_time.inspect}, block=#{job.block.inspect}"
                end

                job.unschedule
              end
            end
          end
        end

        context "Database operations role" do
          before(:each) do
            VMDB::Config.any_instance.stub(:config).and_return(Hash.new(5.minutes))
            @schedule_worker.stub(:heartbeat)

            MiqRegion.seed
            @region = MiqRegion.my_region
            MiqRegion.stub(:my_region).and_return(@region)
            @schedule_worker.instance_variable_set(:@active_roles, ["database_operations"])

            @metrics_collection = { :collection_schedule => "1 * * * *", :daily_rollup_schedule => "23 0 * * *" }
            @metrics_history    = { :purge_schedule => "50 * * * *" }
            database_config     = { :metrics_collection => @metrics_collection, :metrics_history => @metrics_history }
            config              = { :database => database_config }
            vmdb_config = double("vmdb_config")
            vmdb_config.stub(:config => config)
            vmdb_config.stub(:merge_from_template_if_missing)
            VMDB::Config.stub(:new).with("vmdb").and_return(vmdb_config)
          end

          context "with database_owner in region" do
            before(:each) do
              @region.stub(:role_active?).with("database_owner").and_return(true)
            end

            it "queues the right items" do
              scheduled_jobs = @schedule_worker.schedules_for_database_operations_role

              scheduled_jobs.each do |job|
                case job.tags
                when [:database_operations, :database_metrics_collection_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @metrics_collection[:collection_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 1
                  message = MiqQueue.where(:class_name  => "VmdbDatabase", :method_name => "capture_metrics_timer").first
                  message.should_not be_nil
                  message.role.should == "database_owner"
                  message.zone.should be_nil

                  MiqQueue.delete_all
                when [:database_operations, :database_metrics_daily_rollup_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @metrics_collection[:daily_rollup_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 1
                  message = MiqQueue.where(:class_name  => "VmdbDatabase", :method_name => "rollup_metrics_timer").first
                  message.should_not be_nil
                  message.role.should == "database_owner"
                  message.zone.should be_nil

                  MiqQueue.delete_all
                when [:database_operations, :database_metrics_purge_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @metrics_history[:purge_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 2

                  ["VmdbDatabaseMetric", "VmdbMetric"].each do |class_name|
                    message = MiqQueue.where(:class_name  => class_name, :method_name => "purge_all_timer").first
                    message.should_not be_nil
                    message.role.should == "database_operations"
                    message.zone.should be_nil
                  end

                  MiqQueue.delete_all
                else
                  raise "Unexpected Job: tags=#{job.tags.inspect}, t=#{job.t.inspect}, last=#{job.last.inspect}, id=#{job.job_id.inspect}, thr=#{job.last_job_thread.inspect}, next=#{job.next_time.inspect}, block=#{job.block.inspect}"
                end

                job.unschedule
              end
            end
          end

          context "without database_owner in region" do
            before(:each) do
              @region.stub(:role_active?).with("database_owner").and_return(false)
            end

            it "queues the right items" do
              scheduled_jobs = @schedule_worker.schedules_for_database_operations_role

              scheduled_jobs.each do |job|
                case job.tags
                when [:database_operations, :database_metrics_collection_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @metrics_collection[:collection_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 1
                  message = MiqQueue.where(:class_name  => "VmdbDatabase", :method_name => "capture_metrics_timer").first
                  message.should_not be_nil
                  message.role.should == "database_operations"
                  message.zone.should be_nil

                  MiqQueue.delete_all
                when [:database_operations, :database_metrics_daily_rollup_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @metrics_collection[:daily_rollup_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 1
                  message = MiqQueue.where(:class_name  => "VmdbDatabase", :method_name => "rollup_metrics_timer").first
                  message.should_not be_nil
                  message.role.should == "database_operations"
                  message.zone.should be_nil

                  MiqQueue.delete_all
                when [:database_operations, :database_metrics_purge_schedule]
                  job.should be_kind_of(Rufus::Scheduler::CronJob)
                  job.t.should == @metrics_history[:purge_schedule]
                  job.trigger_block
                  @schedule_worker.do_work
                  MiqQueue.count.should == 2

                  ["VmdbDatabaseMetric", "VmdbMetric"].each do |class_name|
                    message = MiqQueue.where(:class_name  => class_name, :method_name => "purge_all_timer").first
                    message.should_not be_nil
                    message.role.should == "database_operations"
                    message.zone.should be_nil
                  end

                  MiqQueue.delete_all
                else
                  raise "Unexpected Job: tags=#{job.tags.inspect}, t=#{job.t.inspect}, last=#{job.last.inspect}, id=#{job.job_id.inspect}, thr=#{job.last_job_thread.inspect}, next=#{job.next_time.inspect}, block=#{job.block.inspect}"
                end

                job.unschedule
              end
            end
          end
        end

        context "end-to-end schedules modified to run every 5 minutes" do
          before(:each) do
            @schedule_worker.stub(:worker_settings).and_return(Hash.new(5.minutes))
            VMDB::Config.any_instance.stub(:config).and_return(Hash.new(5.minutes))
            @schedule_worker.stub(:heartbeat)

            # Initialize active_roles
            @schedule_worker.instance_variable_set(:@active_roles, [])
          end

          context "#schedules_for_all_roles"  do
            before(:each) do
              @schedule_worker.instance_variable_set(:@active_roles, [])
              @start_time = Time.utc(2011, 1, 31, 8, 30, 0)
            end

            it "#do_work schedules work with correct 'first_in' and 'every'" do
              Timecop.freeze(@start_time) do
                @schedule_worker.schedules_for_all_roles

                first_in_expectations = {
                  :vmdb_appliance_log_config   => 5,
                  :log_all_database_statistics => 5,
                  :status_update               => 5,
                  :log_status                  => 5,
                  :log_statistics              => 1
                }

                first_in_expectations.each do |tag, expected_minutes|
                  job = @system.find_by_tag(tag).first
                  expected = @start_time + expected_minutes.minutes
                  job.next_time.should eq(expected), "Schedule tag: #{tag.to_s}"
                  job.frequency.should == 5.minutes
                end
              end
            end

            context "#do_work appliance_specific" do
              it "on an appliance" do
                MiqEnvironment::Command.stub(:is_appliance? => true)
                MiqServer.any_instance.should_receive(:has_assigned_role?).with("rhn_mirror").and_return(true)

                Timecop.freeze(@start_time) do
                  @schedule_worker.schedules_for_all_roles

                  expect(@system.find_by_tag(:server_updates).first.next_time).to eq(@start_time + 1.minutes)
                  expect(@system.find_by_tag(:rhn_mirror).first.next_time).to eq(@start_time + 1.minutes)
                end
              end

              it "not an appliance" do
                MiqEnvironment::Command.stub(:is_appliance? => false)

                Timecop.freeze(@start_time) do
                  @schedule_worker.schedules_for_all_roles

                  expect(@system.find_by_tag(:server_updates).first).to be_nil
                  expect(@system.find_by_tag(:rhn_mirror).first).to be_nil
                end
              end
            end
          end
        end

        context "#schedules_for_event_role" do
          before(:each) do
            @schedule_worker.stub(:heartbeat)
            @schedule_worker.instance_variable_set(:@active_roles, ["event"])
            @schedule_worker.stub(:worker_settings).and_return({:ems_events_purge_interval => 1.day})
            Zone.any_instance.stub(:role_active?).with("event").and_return(true)
          end

          it "queues the right items" do
            scheduled_jobs = @schedule_worker.schedules_for_event_role

            scheduled_jobs.each do |job|
              case job.tags
              when [:ems_event, :purge_schedule]
                job.should be_kind_of(Rufus::Scheduler::EveryJob)
                job.t.should == 1.day
                job.trigger_block
                @schedule_worker.do_work
                MiqQueue.count.should == 1
                message = MiqQueue.where(:class_name  => "EmsEvent", :method_name => "purge_timer").first
                message.should_not be_nil

                MiqQueue.delete_all
              else
                raise "Unexpected Job: tags=#{job.tags.inspect}, t=#{job.t.inspect}, last=#{job.last.inspect}, id=#{job.job_id.inspect}, thr=#{job.last_job_thread.inspect}, next=#{job.next_time.inspect}, block=#{job.block.inspect}"
              end

              job.unschedule
            end
          end
        end
      end

      it "should never sync_all_user_schedules if scheduler role disabled" do
        @schedule_worker.instance_variable_set(:@active_roles, [])
        @schedule_worker.should_receive(:sync_all_user_schedules).never
        @schedule_worker.load_user_schedules
      end

      it "should sync_all_user_schedules if scheduler role enabled" do
        @schedule_worker.instance_variable_set(:@active_roles, ['scheduler'])
        @schedule_worker.should_receive(:sync_all_user_schedules).once
        @schedule_worker.load_user_schedules
      end
    end

    context "with Daylight Savings Time changes" do
      before do
        @schedule_worker.stub(:dst?).and_return(true)
        @schedule_worker.reset_dst
      end

      it "should not invoke after_dst_change callbacks if Daylight Savings Time is unchanged" do
        @schedule_worker.should_receive(:load_user_schedules).never
        @schedule_worker.check_dst
      end

      it "should invoke after_dst_change callbacks only once if Daylight Savings Time changes" do
        @schedule_worker.stub(:dst?).and_return(false)
        @schedule_worker.should_receive(:load_user_schedules).once
        @schedule_worker.check_dst
        @schedule_worker.check_dst
      end
    end
  end
end
