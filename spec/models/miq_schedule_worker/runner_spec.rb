describe MiqScheduleWorker::Runner do
  context ".new" do
    before do
      @miq_server = EvmSpecHelper.local_miq_server(:is_master => true)
      @zone = @miq_server.zone

      worker_guid = SecureRandom.uuid
      @worker = FactoryGirl.create(:miq_schedule_worker, :guid => worker_guid, :miq_server_id => @miq_server.id)

      allow_any_instance_of(MiqScheduleWorker::Runner).to receive(:initialize_rufus)
      allow_any_instance_of(MiqScheduleWorker::Runner).to receive(:sync_config)
      allow_any_instance_of(MiqScheduleWorker::Runner).to receive(:set_connection_pool_size)

      @schedule_worker = MiqScheduleWorker::Runner.new(:guid => worker_guid)
    end

    context "with a stuck dispatch in each zone" do
      before do
        @cond = {:class_name => 'JobProxyDispatcher', :method_name => 'dispatch'}
        @opts = @cond.merge(:state => 'dequeue', :updated_on => Time.now.utc)
        @stale_timeout = 2.minutes
        allow(@schedule_worker).to receive(:worker_settings).and_return(:job_proxy_dispatcher_stale_message_timeout => @stale_timeout)

        @zone1 = @zone
        @worker1 = FactoryGirl.create(:miq_worker, :status => MiqWorker::STATUS_STOPPED)
        @dispatch1 = FactoryGirl.create(:miq_queue, {:zone => @zone1.name, :handler_type => @worker1.class.name, :handler_id => @worker1.id}.merge(@opts))

        @zone2 = FactoryGirl.create(:zone)
        @worker2 = FactoryGirl.create(:miq_worker, :status => MiqWorker::STATUS_STOPPED)

        allow(MiqServer).to receive(:my_zone).and_return(@zone1.name)
        Timecop.travel 5.minutes
      end

      after do
        Timecop.return
      end

      it "check_for_dispatch calls check_for_timeout which deletes both dispatches with fixnum" do
        attrs = {:zone       => @zone2.name, :handler_type => @worker2.class.name,
                 :handler_id => @worker2.id}
        @dispatch2 = FactoryGirl.create(:miq_queue, attrs.merge(@opts))

        expect(MiqQueue.where(@cond).count).to eq(2)
        MiqScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout.to_i)
        expect(MiqQueue.where(@cond).count).to eq(0)
      end

      it "check_for_dispatch calls check_for_timeout which deletes both dispatches" do
        attrs = {:zone       => @zone2.name, :handler_type => @worker2.class.name,
                 :handler_id => @worker2.id}
        @dispatch2 = FactoryGirl.create(:miq_queue, attrs.merge(@opts))

        expect(MiqQueue.where(@cond).count).to eq(2)
        MiqScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
        expect(MiqQueue.where(@cond).count).to eq(0)
      end

      it "check_for_dispatch calls check_for_timeout with triple threshold for active worker" do
        @worker1.update_attribute(:status, MiqWorker::STATUS_STARTED)
        expect_any_instance_of(MiqQueue).to receive(:check_for_timeout).once do |_instance, _prefix, _grace, timeout|
          expect(timeout).to eq(@stale_timeout * 3)
        end
        MiqScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
      end

      it "check_for_dispatch calls check_for_timeout with threshold for inactive worker" do
        expect_any_instance_of(MiqQueue).to receive(:check_for_timeout).once do |_instance, _prefix, _grace, timeout|
          expect(timeout).to eq(@stale_timeout)
        end
        MiqScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
      end

      it "check_for_dispatch calls check_for_timeout which deletes for in-active worker" do
        @dispatch2 = FactoryGirl.create(:miq_queue, {:zone => @zone2.name, :handler_type => @worker2.class.name, :handler_id => @worker2.id}.merge(@opts))

        @worker1.update_attribute(:status, MiqWorker::STATUS_STARTED)
        cond_active = @cond.dup
        cond_active[:handler_id] = @worker1.id
        expect(MiqQueue.where(@cond).count).to eq(2)
        MiqScheduleWorker::Jobs.new.check_for_stuck_dispatch(@stale_timeout)
        expect(MiqQueue.where(@cond).count).to eq(1)
        expect(MiqQueue.where(cond_active).count).to eq(1)
      end
    end

    context "with Time before DST" do
      before do
        @start = Time.parse('Sun November 6 01:00:00 -0400 2010')
        @east_tz = 'Eastern Time (US & Canada)'
        Timecop.travel(@start)
        @schedule_worker.reset_dst
      end

      after do
        Timecop.return
      end

      context "using Rufus::Scheduler" do
        before do
          rufus_frequency = 0.00001  # How often rufus will check for jobs to do
          require 'rufus/scheduler'
          @schedule_worker.instance_eval do
            @system_scheduler = Rufus::Scheduler.new(:frequency => rufus_frequency)
            @user_scheduler   = Rufus::Scheduler.new(:frequency => rufus_frequency)
          end
          @user = @schedule_worker.instance_variable_get(:@user_scheduler)
          @system = @schedule_worker.instance_variable_get(:@system_scheduler)
        end

        after do
          @user.stop
          @system.stop
          @user = nil
          @system = nil
        end

        it "monthly schedule scheduled for 5 years will be unscheduled by tag" do
          first_at = Time.utc(2011, 1, 1, 8, 30)
          tag = "miq_schedules_1"
          @sch = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2011-01-01 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})
          @schedule_worker.rufus_add_schedule(:method => :schedule_at, :interval => first_at, :months => 1, :schedule_id => @sch.id, :discard_past => true, :tags => tag)
          expect(@schedule_worker.queue_length).to eq(0)

          @schedule_worker.rufus_remove_schedules_by_tag(tag)

          expect(@user.jobs(:tag => tag)).to be_empty
        end

        it "monthly creates a schedule each month for 5 years" do
          first_at = Time.utc(2011, 1, 1, 8, 30)
          @sch = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2011-01-01 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})

          Timecop.freeze(first_at - 1.minute) do
            @schedule_worker.rufus_add_schedule(:method => :schedule_at, :interval => first_at, :months => 1, :schedule_id => @sch.id, :discard_past => true, :tags => "miq_schedules_1")
            schedules = @schedule_worker.instance_variable_get(:@schedules)
            expect(schedules[:scheduler].length).to eq(60)
          end
          @user.jobs(:tag => "miq_schedules_1").each_with_index do |job, i|
            expect(job.next_time).to eq(first_at + i.month)
          end
        end

        it "monthly schedule starting Jan 31 will next run Feb 28" do
          first_at = Time.utc(2011, 1, 31, 8, 30)
          @sch = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2011-01-31 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})

          Timecop.freeze(first_at + 1.minute) do
            @schedule_worker.rufus_add_schedule(:method => :schedule_at, :interval => first_at, :months => 1, :schedule_id => @sch.id, :discard_past => true, :tags => "miq_schedules_1")

            job = @user.jobs(:tag => "miq_schedules_1").first
            expect(job.next_time).to eq(Time.utc(2011, 2, 28, 8, 30, 0))
          end
        end

        describe "#rufus_add_normal_schedule" do
          context "with the cron method" do
            it "adds jobs to the worker's schedules" do
              @schedule_worker.instance_variable_set(:@schedules, :scheduler => [])
              interval = "0 2 * * *"
              options = {
                :method      => :cron,
                :interval    => interval,
                :schedule_id => "12345"
              }

              @schedule_worker.rufus_add_normal_schedule(options)

              jobs = @schedule_worker.instance_variable_get(:@schedules)[:scheduler]
              expect(jobs).to be_all { |job| job.kind_of?(Rufus::Scheduler::Job) }
            end
          end
        end

        context "calling check_roles_changed" do
          before do
            allow(@schedule_worker).to receive(:worker_settings).and_return(Hash.new(5.minutes))
            @schedule_worker.instance_variable_set(:@schedules, :scheduler => [])

            @sch1 = FactoryGirl.create(:miq_schedule)
            @sch2 = FactoryGirl.create(:miq_schedule)
          end

          it "should load all user schedules when scheduler role is added" do
            @schedule_worker.instance_variable_set(:@active_roles,  ["scheduler"])
            @schedule_worker.instance_variable_set(:@current_roles, [])

            expect(@user.jobs.length).to eq(0)

            @schedule_worker.schedules_for_scheduler_role
            expect(@system.jobs.length).to be > 0

            @schedule_worker.check_roles_changed
            expect(@user.jobs.length).to eq(2)
          end

          it "should unload all user schedules when scheduler role is removed" do
            # start with with scheduler role
            @schedule_worker.instance_variable_set(:@active_roles,  ["scheduler"])
            @schedule_worker.instance_variable_set(:@current_roles, [])

            @schedule_worker.schedules_for_scheduler_role
            expect(@system.jobs.length).to be > 0

            @schedule_worker.sync_all_user_schedules
            expect(@user.jobs.length).to eq(2)

            # Make sure only real schedules are processed
            schedules = @schedule_worker.instance_variable_get(:@schedules)
            schedules[:scheduler] << nil
            @schedule_worker.instance_variable_set(:@schedules, schedules)

            # remove scheduler role
            @schedule_worker.instance_variable_set(:@active_roles,  [])
            @schedule_worker.instance_variable_set(:@current_roles, ["scheduler"])
            @schedule_worker.check_roles_changed

            expect(@system.jobs.length).to eq(0)
            expect(@user.jobs.length).to eq(0)
          end
        end

        context "Database operations role" do
          before do
            allow(@schedule_worker).to receive(:heartbeat)

            @region = MiqRegion.seed
            allow(MiqRegion).to receive(:my_region).and_return(@region)
            @schedule_worker.instance_variable_set(:@active_roles, ["database_operations"])

            @metrics_collection = {:collection_schedule => "1 * * * *", :daily_rollup_schedule => "23 0 * * *"}
            @metrics_history    = {:purge_schedule => "50 * * * *"}
            @database_maintenance = {
              :reindex_schedule => "1 * * * *",
              :reindex_tables   => %w(Metric MiqQueue MiqWorker),
              :vacuum_schedule  => "0 2 * * 6",
              :vacuum_tables    => %w(Vm BinaryBlobPart BinaryBlob CustomizationSpec FirewallRule Host Storage
                                      MiqSchedule EventLog PolicyEvent Snapshot Job Network MiqQueue MiqRequestTask
                                      MiqWorker MiqServer MiqSearch MiqScsiLun MiqScsiTarget StorageFile
                                      Tagging VimPerformanceState)
            }
            database_config = {
              :maintenance        => @database_maintenance,
              :metrics_collection => @metrics_collection,
              :metrics_history    => @metrics_history,
            }
            stub_settings(:database => database_config)
          end

          context "with database_owner in region" do
            before do
              allow(@region).to receive(:role_active?).with("database_owner").and_return(true)
            end

            it "queues the right items" do
              scheduled_jobs = @schedule_worker.schedules_for_database_operations_role
              expect(scheduled_jobs.size).to be(5)

              scheduled_jobs.each do |job|
                expect(job).to be_a_kind_of(Rufus::Scheduler::CronJob)

                while_calling_job(job) do
                  case job.tags
                  when %w(database_operations database_metrics_collection_schedule)
                    expect(job.original).to eq(@metrics_collection[:collection_schedule])
                    expect(MiqQueue.count).to eq(1)
                    message = MiqQueue.where(:class_name  => "VmdbDatabase",
                                             :method_name => "capture_metrics_timer").first
                    expect(message).to have_attributes(:role => "database_owner", :zone => nil)
                  when %w(database_operations database_metrics_daily_rollup_schedule)
                    expect(job.original).to eq(@metrics_collection[:daily_rollup_schedule])
                    expect(MiqQueue.count).to eq(1)
                    message = MiqQueue.where(:class_name  => "VmdbDatabase",
                                             :method_name => "rollup_metrics_timer").first
                    expect(message).to have_attributes(:role => "database_owner", :zone => nil)
                  when %w(database_operations database_metrics_purge_schedule)
                    expect(job.original).to eq(@metrics_history[:purge_schedule])
                    expect(MiqQueue.count).to eq(2)
                    %w(VmdbDatabaseMetric VmdbMetric).each do |class_name|
                      message = MiqQueue.where(:class_name => class_name, :method_name => "purge_all_timer").first
                      expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                    end
                  when %w(database_operations database_maintenance_reindex_schedule)
                    expect(job.original).to eq(@database_maintenance[:reindex_schedule])
                    expect(MiqQueue.count).to eq(3)
                    @database_maintenance[:reindex_tables].each do |class_name|
                      message = MiqQueue.where(:class_name => class_name, :method_name => "reindex").first
                      expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                    end
                  when %w(database_operations database_maintenance_vacuum_schedule)
                    expect(job.original).to eq(@database_maintenance[:vacuum_schedule])
                    expect(MiqQueue.count).to eq(@database_maintenance[:vacuum_tables].size)
                    @database_maintenance[:vacuum_tables].each do |class_name|
                      message = MiqQueue.where(:class_name => class_name, :method_name => "vacuum").first
                      expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                    end
                  else
                    raise_unexpected_job_error(job)
                  end
                end
              end
            end
          end

          context "without database_owner in region" do
            before do
              allow(@region).to receive(:role_active?).with("database_owner").and_return(false)
            end

            it "queues the right items" do
              scheduled_jobs = @schedule_worker.schedules_for_database_operations_role
              expect(scheduled_jobs.size).to be(5)

              scheduled_jobs.each do |job|
                expect(job).to be_kind_of(Rufus::Scheduler::CronJob)

                while_calling_job(job) do
                  case job.tags
                  when %w(database_operations database_metrics_collection_schedule)
                    expect(job.original).to eq(@metrics_collection[:collection_schedule])
                    expect(MiqQueue.count).to eq(1)
                    message = MiqQueue.where(:class_name  => "VmdbDatabase",
                                             :method_name => "capture_metrics_timer").first
                    expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                  when %w(database_operations database_metrics_daily_rollup_schedule)
                    expect(job.original).to eq(@metrics_collection[:daily_rollup_schedule])
                    expect(MiqQueue.count).to eq(1)
                    message = MiqQueue.where(:class_name  => "VmdbDatabase",
                                             :method_name => "rollup_metrics_timer").first
                    expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                  when %w(database_operations database_metrics_purge_schedule)
                    expect(job.original).to eq(@metrics_history[:purge_schedule])
                    expect(MiqQueue.count).to eq(2)

                    %w(VmdbDatabaseMetric VmdbMetric).each do |class_name|
                      message = MiqQueue.where(:class_name => class_name, :method_name => "purge_all_timer").first
                      expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                    end
                  when %w(database_operations database_maintenance_reindex_schedule)
                    expect(job.original).to eq(@database_maintenance[:reindex_schedule])
                    expect(MiqQueue.count).to eq(3)
                    @database_maintenance[:reindex_tables].each do |class_name|
                      message = MiqQueue.where(:class_name => class_name, :method_name => "reindex").first
                      expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                    end
                  when %w(database_operations database_maintenance_vacuum_schedule)
                    expect(job.original).to eq(@database_maintenance[:vacuum_schedule])
                    expect(MiqQueue.count).to eq(@database_maintenance[:vacuum_tables].size)
                    @database_maintenance[:vacuum_tables].each do |class_name|
                      message = MiqQueue.where(:class_name => class_name, :method_name => "vacuum").first
                      expect(message).to have_attributes(:role => "database_operations", :zone => nil)
                    end
                  else
                    raise_unexpected_job_error(job)
                  end
                end
              end
            end
          end
        end

        context "end-to-end schedules modified to run every 5 minutes" do
          before do
            allow(@schedule_worker).to receive(:worker_settings).and_return(Hash.new(5.minutes))
            stub_settings(Hash.new(5.minutes))
            allow(@schedule_worker).to receive(:heartbeat)

            # Initialize active_roles
            @schedule_worker.instance_variable_set(:@active_roles, [])
          end

          context "#schedules_for_all_roles"  do
            before do
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
                  job = @system.jobs(:tag => tag).first
                  expected = @start_time + expected_minutes.minutes
                  expect(job.next_time).to eq(expected), "Schedule tag: #{tag}"
                  expect(job.frequency).to eq(5.minutes)
                end
              end
            end

            context "#do_work appliance_specific" do
              it "on an appliance" do
                allow(MiqEnvironment::Command).to receive_messages(:is_appliance? => true)

                Timecop.freeze(@start_time) do
                  @schedule_worker.schedules_for_all_roles

                  expect(@system.jobs(:tag => :server_updates).first.next_time).to eq(@start_time + 1.minute)
                end
              end

              it "not an appliance" do
                allow(MiqEnvironment::Command).to receive_messages(:is_appliance? => false)

                Timecop.freeze(@start_time) do
                  @schedule_worker.schedules_for_all_roles

                  expect(@system.jobs(:tag => :server_updates).first).to be_nil
                end
              end
            end
          end
        end

        context "#schedules_for_event_role" do
          before do
            allow(@schedule_worker).to receive(:heartbeat)
            @schedule_worker.instance_variable_set(:@active_roles, ["event"])
            allow(@schedule_worker).to receive(:worker_settings).and_return(:event_streams_purge_interval => 1.day,
                                                                            :policy_events_purge_interval => 1.day)
            allow_any_instance_of(Zone).to receive(:role_active?).with("event").and_return(true)
          end

          it "queues the right items" do
            scheduled_jobs = @schedule_worker.schedules_for_event_role
            expect(scheduled_jobs.size).to be(2)

            scheduled_jobs.each do |job|
              expect(job).to be_kind_of(Rufus::Scheduler::EveryJob)
              expect(job.original).to eq(1.day)

              while_calling_job(job) do
                case job.tags
                when %w(event_stream purge_schedule)
                  messages = MiqQueue.where(:class_name => "EventStream", :method_name => "purge_timer")
                  expect(messages.count).to eq(1)
                when %w(policy_event purge_schedule)
                  messages = MiqQueue.where(:class_name => "PolicyEvent", :method_name => "purge_timer")
                  expect(messages.count).to eq(1)
                else
                  raise_unexpected_job_error(job)
                end
              end
            end
          end
        end

        context "schedule for 'scheduler' role" do
          before do
            allow(@schedule_worker).to receive(:heartbeat)
            @schedule_worker.instance_variable_set(:@active_roles, ["scheduler"])
            @schedule_worker.instance_variable_set(:@schedules, :scheduler => [])
          end

          describe "#schedule_chargeback_report_for_service_daily" do
            before do
              allow(@schedule_worker).to receive(:worker_settings).and_return(:chargeback_generation_interval => 1.day)
            end

            it "queues daily generation of Chargeback report for each service" do
              job = @schedule_worker.schedule_chargeback_report_for_service_daily[0]
              expect(job).to be_kind_of(Rufus::Scheduler::EveryJob)
              expect(job.original).to eq(1.day)
              job.call
              @schedule_worker.do_work
              expect(MiqQueue.count).to eq 1
              queue = MiqQueue.first
              expect(queue.method_name).to eq "queue_chargeback_reports"
              expect(queue.class_name).to eq "Service"
              expect(queue.args[0][:report_source]).to eq "Daily scheduler"
              MiqQueue.delete_all
              job.unschedule
            end
          end

          describe "#schedule_check_for_task_timeout" do
            let(:interval) { 1.hour }
            before do
              allow(@schedule_worker).to receive(:worker_settings).and_return(:task_timeout_check_frequency => interval)
            end

            it "queues check for timed out tasks" do
              job = @schedule_worker.schedule_check_for_task_timeout[0]
              job.call
              @schedule_worker.do_work
              queue = MiqQueue.first
              expect(queue.method_name).to eq "update_status_for_timed_out_active_tasks"
              expect(queue.class_name).to eq "MiqTask"
              MiqQueue.delete_all
              job.unschedule
            end
          end
        end
      end

      it "should never sync_all_user_schedules if scheduler role disabled" do
        @schedule_worker.instance_variable_set(:@active_roles, [])
        expect(@schedule_worker).to receive(:sync_all_user_schedules).never
        @schedule_worker.load_user_schedules
      end

      it "should sync_all_user_schedules if scheduler role enabled" do
        @schedule_worker.instance_variable_set(:@active_roles, ['scheduler'])
        expect(@schedule_worker).to receive(:sync_all_user_schedules).once
        @schedule_worker.load_user_schedules
      end
    end

    context "with Daylight Savings Time changes" do
      before do
        allow(@schedule_worker).to receive(:dst?).and_return(true)
        @schedule_worker.reset_dst
      end

      it "should not invoke after_dst_change callbacks if Daylight Savings Time is unchanged" do
        expect(@schedule_worker).to receive(:load_user_schedules).never
        @schedule_worker.check_dst
      end

      it "should invoke after_dst_change callbacks only once if Daylight Savings Time changes" do
        allow(@schedule_worker).to receive(:dst?).and_return(false)
        expect(@schedule_worker).to receive(:load_user_schedules).once
        @schedule_worker.check_dst
        @schedule_worker.check_dst
      end
    end

    it "#schedule_settings_for_ems_refresh (private)" do
      _ = ManageIQ::Providers::Microsoft::InfraManager # FIXME: Loader

      stub_settings(
        :ems_refresh => {
          :refresh_interval => 24.hours,
          :scvmm            => {:refresh_interval => 15.minutes}
        }
      )

      settings = @schedule_worker.send(:schedule_settings_for_ems_refresh)

      expect(settings[ManageIQ::Providers::Vmware::InfraManager]).to    eq(86_400) # Uses default
      expect(settings[ManageIQ::Providers::Microsoft::InfraManager]).to eq(900)    # Uses override
    end

    def while_calling_job(job)
      job.call
      @schedule_worker.do_work
      yield
    ensure
      MiqQueue.delete_all
      job.unschedule
    end

    def raise_unexpected_job_error(job)
      raise "Unexpected Job: tags=#{job.tags.inspect}, original=#{job.original.inspect}, "\
            "last_time=#{job.last_time.inspect}, id=#{job.job_id.inspect}, next=#{job.next_time.inspect}, "\
            "handler=#{job.handler.inspect}"
    end
  end
end
