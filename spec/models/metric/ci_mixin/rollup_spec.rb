describe Metric::CiMixin::Rollup do
  before do
    MiqRegion.seed

    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".perf_rollup" do
    context "with enabled and disabled targets", :with_enabled_disabled_vmware do
      context "executing perf_capture_timer" do
        before do
          @expected_targets = all_targets
          stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
          Metric::Capture.perf_capture_timer(@ems_vmware.id)
        end

        context "executing capture_ems_targets for realtime targets with parent objects" do
          before do
            @expected_targets = Metric::Targets.capture_ems_targets(@ems_vmware)
          end

          it "should create tasks and queue callbacks for perf_capture_timer" do
            # stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
            # Metric::Capture.perf_capture_timer(@ems_vmware.id)
            @vmware_clusters.each do |cluster|
              expected_hosts = cluster.hosts.select { |h| @expected_targets.include?(h) }
              next if expected_hosts.empty?

              task = MiqTask.find_by(:name => "Performance rollup for EmsCluster:#{cluster.id}")
              expect(task).not_to be_nil
              expect(task.context_data[:targets]).to match_array(cluster.hosts.collect { |h| "ManageIQ::Providers::Vmware::InfraManager::Host:#{h.id}" })

              expected_hosts.each do |host|
                messages = MiqQueue.where(:class_name  => 'ManageIQ::Providers::Vmware::InfraManager::Host',
                                          :instance_id => host.id,
                                          :method_name => "perf_capture_realtime")
                expect(messages.size).to eq(1)
                messages.each do |m|
                  expect(m.miq_callback).not_to be_nil
                  expect(m.miq_callback[:method_name]).to eq(:perf_capture_callback)
                  expect(m.miq_callback[:args]).to eq([[task.id]])

                  m.delivered("ok", "Message delivered successfully", nil)
                end
              end

              task.reload
              expect(task.state).to eq("Finished")

              message = MiqQueue.find_by(:method_name => "perf_rollup_range", :class_name => "EmsCluster", :instance_id => cluster.id)
              expect(message).not_to be_nil
              expect(message.args).to eq([task.context_data[:start], task.context_data[:end], task.context_data[:interval], nil])
            end
          end

          it "calling perf_capture_timer when existing capture messages are on the queue should merge messages and append new task id to cb args" do
            # stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
            # Metric::Capture.perf_capture_timer(@ems_vmware.id)
            Metric::Capture.perf_capture_timer(@ems_vmware.id)
            @vmware_clusters.each do |cluster|
              expected_hosts = cluster.hosts.select { |h| @expected_targets.include?(h) }
              next if expected_hosts.empty?

              tasks = MiqTask.where(:name => "Performance rollup for EmsCluster:#{cluster.id}").order("id DESC")
              expect(tasks.length).to eq(2)
              tasks.each do |task|
                expect(task.context_data[:targets]).to match_array(cluster.hosts.collect { |h| "ManageIQ::Providers::Vmware::InfraManager::Host:#{h.id}" })
              end

              task_ids = tasks.collect(&:id)

              expected_hosts.each do |host|
                messages = MiqQueue.where(:class_name  => 'ManageIQ::Providers::Vmware::InfraManager::Host',
                                          :instance_id => host.id,
                                          :method_name => "perf_capture_realtime")
                expect(messages.size).to eq(1)
                host.update_attribute(:last_perf_capture_on, 1.minute.from_now.utc)
                messages.each do |m|
                  next if m.miq_callback[:args].blank?

                  expect(m.miq_callback).not_to be_nil
                  expect(m.miq_callback[:method_name]).to eq(:perf_capture_callback)
                  expect(m.miq_callback[:args].first.sort).to eq(task_ids.sort)

                  status, message, result = m.deliver
                  m.delivered(status, message, result)
                end
              end

              tasks.each do |task|
                task.reload
                expect(task.state).to eq("Finished")
              end
            end
          end

          it "calling perf_capture_timer a second time should create another task with the correct time window" do
            # Metric::Capture.perf_capture_timer(@ems_vmware.id)
            Metric::Capture.perf_capture_timer(@ems_vmware.id)

            @vmware_clusters.each do |cluster|
              expected_hosts = cluster.hosts.select { |h| @expected_targets.include?(h) }
              next if expected_hosts.empty?

              tasks = MiqTask.where(:name => "Performance rollup for EmsCluster:#{cluster.id}").order("id")
              expect(tasks.length).to eq(2)

              t1, t2 = tasks
              expect(t2.context_data[:start]).to eq(t1.context_data[:end])
            end
          end
        end
      end
    end

    context "with Vm realtime performances", :with_small_vmware do
      before do
        cases = [
          "2010-04-14T20:52:30Z", 100.0,
          "2010-04-14T21:51:10Z", 1.0,
          "2010-04-14T21:51:30Z", 2.0,
          "2010-04-14T21:51:50Z", 4.0,
          "2010-04-14T21:52:10Z", 8.0,
          "2010-04-14T21:52:30Z", 15.0,
          "2010-04-14T22:52:30Z", 100.0,
        ]
        cases.each_slice(2) do |t, v|
          @vm1.metrics << FactoryBot.create(:metric_vm_rt,
                                             :timestamp                  => t,
                                             :cpu_usage_rate_average     => v,
                                             :cpu_ready_delta_summation  => v * 1000, # Multiply by a factor of 1000 to maake it more realistic and enable testing virtual col v_pct_cpu_ready_delta_summation
                                             :sys_uptime_absolute_latest => v
                                            )
        end
      end

      ## MetricRollup ci/rollup.perf_rollup
      context "calling perf_rollup to hourly on the Vm" do
        before do
          @vm1.perf_rollup("2010-04-14T21:00:00Z", 'hourly')
        end

        it "should rollup Vm realtime into Vm hourly rows correctly" do
          expect(MetricRollup.hourly.count).to eq(1)
          perf = MetricRollup.hourly.first

          expect(perf.resource_type).to eq('VmOrTemplate')
          expect(perf.resource_id).to eq(@vm1.id)
          expect(perf.capture_interval_name).to eq('hourly')
          expect(perf.timestamp.iso8601).to eq("2010-04-14T21:00:00Z")

          expect(perf.cpu_usage_rate_average).to eq(6.0)
          expect(perf.cpu_ready_delta_summation).to eq(30000.0)
          expect(perf.v_pct_cpu_ready_delta_summation).to eq(30.0)
          expect(perf.sys_uptime_absolute_latest).to eq(15.0)

          expect(perf.abs_max_cpu_usage_rate_average_value).to eq(15.0)
          expect(perf.abs_max_cpu_usage_rate_average_timestamp.utc.iso8601).to eq("2010-04-14T21:52:30Z")

          perf.abs_min_cpu_usage_rate_average_value == 1.0
          perf.abs_min_cpu_usage_rate_average_timestamp.utc.iso8601 == "2010-04-14T21:51:10Z"
        end
      end
    end

    context "with Vm hourly performances", :with_small_vmware do
      before do
        cases = [
          "2010-04-13T21:00:00Z", 100.0,
          "2010-04-14T18:00:00Z", 1.0,
          "2010-04-14T19:00:00Z", 2.0,
          "2010-04-14T20:00:00Z", 4.0,
          "2010-04-14T21:00:00Z", 8.0,
          "2010-04-14T22:00:00Z", 15.0,
          "2010-04-15T21:00:00Z", 100.0,
        ]
        cases.each_slice(2) do |t, v|
          @vm1.metric_rollups << FactoryBot.create(:metric_rollup_vm_hr,
                                                    :timestamp                  => t,
                                                    :cpu_usage_rate_average     => v,
                                                    :cpu_ready_delta_summation  => v * 10000,
                                                    :sys_uptime_absolute_latest => v,
                                                    :min_max                    => {
                                                      :abs_max_cpu_usage_rate_average_value     => v,
                                                      :abs_max_cpu_usage_rate_average_timestamp => Time.parse(t) + 20.seconds,
                                                      :abs_min_cpu_usage_rate_average_value     => v,
                                                      :abs_min_cpu_usage_rate_average_timestamp => Time.parse(t) + 40.seconds,
                                                    }
                                                   )
        end
      end

      context "calling perf_rollup to daily on the Vm" do
        before do
          @vm1.perf_rollup("2010-04-14T00:00:00Z", 'daily', @time_profile.id)
        end

        it "should rollup Vm hourly into Vm daily rows correctly" do
          expect(MetricRollup.daily.count).to eq(1)
          perf = MetricRollup.daily.first

          expect(perf.resource_type).to eq('VmOrTemplate')
          expect(perf.resource_id).to eq(@vm1.id)
          expect(perf.capture_interval_name).to eq('daily')
          expect(perf.timestamp.iso8601).to eq("2010-04-14T00:00:00Z")
          expect(perf.time_profile_id).to eq(@time_profile.id)

          expect(perf.cpu_usage_rate_average).to eq(6.0)
          expect(perf.cpu_ready_delta_summation).to eq(60000.0) # actually uses average
          expect(perf.v_pct_cpu_ready_delta_summation).to eq(1.7)
          expect(perf.sys_uptime_absolute_latest).to eq(6.0)     # actually uses average

          expect(perf.max_cpu_usage_rate_average).to eq(15.0)
          expect(perf.abs_max_cpu_usage_rate_average_value).to eq(15.0)
          expect(perf.abs_max_cpu_usage_rate_average_timestamp.utc.iso8601).to eq("2010-04-14T22:00:20Z")

          expect(perf.min_cpu_usage_rate_average).to eq(1.0)
          expect(perf.abs_min_cpu_usage_rate_average_value).to eq(1.0)
          expect(perf.abs_min_cpu_usage_rate_average_timestamp.utc.iso8601).to eq("2010-04-14T18:00:40Z")
        end

        it "will have created an operating range" do
          vpors = @vm1.vim_performance_operating_ranges
          expect(vpors.size).to               eq(1)
          expect(vpors.first.time_profile).to eq(@time_profile)
        end
      end

      context "calling perf_rollup_range to daily on the Vm" do
        before do
          @vm1.perf_rollup_range("2010-04-13T00:00:00Z", "2010-04-15T00:00:00Z", 'daily', @time_profile.id)
        end

        it "should rollup Vm hourly into Vm daily rows correctly" do
          perfs = MetricRollup.daily
          expect(perfs.length).to eq(3)
          expect(perfs.collect { |r| r.timestamp.iso8601 }).to match_array(
            ["2010-04-13T00:00:00Z", "2010-04-14T00:00:00Z", "2010-04-15T00:00:00Z"])
        end
      end

      context "and Host realtime performances" do
        before do
          cases = [
            "2010-04-14T20:52:40Z", 100.0,
            "2010-04-14T21:51:20Z", 2.0,
            "2010-04-14T21:51:40Z", 4.0,
            "2010-04-14T21:52:00Z", 8.0,
            "2010-04-14T21:52:20Z", 16.0,
            "2010-04-14T21:52:40Z", 30.0,
            "2010-04-14T22:52:40Z", 100.0,
          ]
          cases.each_slice(2) do |t, v|
            @host1.metrics << FactoryBot.create(:metric_host_rt,
                                                 :timestamp                  => t,
                                                 :cpu_usage_rate_average     => v,
                                                 :cpu_usagemhz_rate_average  => v,
                                                 :sys_uptime_absolute_latest => v
                                                )
          end

          cases = [
            "2010-04-14T20:52:40Z", 200.0,
            "2010-04-14T21:51:20Z", 3.0,
            "2010-04-14T21:51:40Z", 8.0,
            "2010-04-14T21:52:00Z", 16.0,
            "2010-04-14T21:52:20Z", 32.0,
            "2010-04-14T21:52:40Z", 60.0,
            "2010-04-14T22:52:40Z", 200.0,
          ]
          cases.each_slice(2) do |t, v|
            @host2.metrics << FactoryBot.create(:metric_host_rt,
                                                 :timestamp                  => t,
                                                 :cpu_usage_rate_average     => v,
                                                 :cpu_usagemhz_rate_average  => v,
                                                 :sys_uptime_absolute_latest => v
                                                )
          end
        end

        context "calling perf_rollup to hourly on the Host" do
          before do
            @host1.perf_rollup("2010-04-14T21:00:00Z", 'hourly')
          end

          it "should rollup Host realtime and Vm hourly into Host hourly rows correctly" do
            expect(MetricRollup.hourly.where(:resource_type => 'Host', :resource_id => @host1.id).count).to eq(1)
            perf = MetricRollup.hourly.where(:resource_type => 'Host', :resource_id => @host1.id).first

            expect(perf.resource_type).to eq('Host')
            expect(perf.resource_id).to eq(@host1.id)
            expect(perf.capture_interval_name).to eq('hourly')
            expect(perf.timestamp.iso8601).to eq("2010-04-14T21:00:00Z")

            expect(perf.cpu_usage_rate_average).to eq(12.0)    # pulled from Host realtime
            expect(perf.cpu_ready_delta_summation).to eq(80000.0) # pulled from Vm hourly
            expect(perf.v_pct_cpu_ready_delta_summation).to eq(2.2)
            expect(perf.sys_uptime_absolute_latest).to eq(30.0)    # pulled from Host realtime

            # NOTE: min / max / burst are only pulled in from Vm realtime.
          end
        end

        context "calling perf_rollup_range to realtime on the parent Cluster" do
          before do
            @ems_cluster.perf_rollup_range("2010-04-14T21:51:20Z", "2010-04-14T21:52:40Z", 'realtime')
          end

          it "should rollup Host realtime Cluster realtime rows correctly" do
            expect(Metric.where(:resource_type => 'EmsCluster', :resource_id => @ems_cluster.id).count).to eq(5)
            perfs = Metric.where(:resource_type => 'EmsCluster', :resource_id => @ems_cluster.id).order("timestamp")

            expect(perfs[0].resource_type).to eq('EmsCluster')
            expect(perfs[0].resource_id).to eq(@ems_cluster.id)
            expect(perfs[0].capture_interval_name).to eq('realtime')
            expect(perfs[0].timestamp.iso8601).to eq("2010-04-14T21:51:20Z")

            expect(perfs[0].cpu_usage_rate_average).to eq(2.5) # pulled from Host realtime
            expect(perfs[0].cpu_usagemhz_rate_average).to eq(5.0) # pulled from Host realtime
            expect(perfs[0].sys_uptime_absolute_latest).to eq(3.0) # pulled from Host realtime
            expect(perfs[0].derived_cpu_available).to eq(19152)

            expect(perfs[2].cpu_usage_rate_average).to eq(12.0)  # pulled from Host realtime
            expect(perfs[2].cpu_usagemhz_rate_average).to eq(24.0)  # pulled from Host realtime
            expect(perfs[2].sys_uptime_absolute_latest).to eq(16.0)  # pulled from Host realtime
            expect(perfs[2].derived_cpu_available).to eq(19152)

            expect(perfs[3].cpu_usage_rate_average).to eq(24.0)  # pulled from Host realtime
            expect(perfs[3].cpu_usagemhz_rate_average).to eq(48.0)  # pulled from Host realtime
            expect(perfs[3].sys_uptime_absolute_latest).to eq(32.0)  # pulled from Host realtime
            expect(perfs[3].derived_cpu_available).to eq(19152)
          end
        end
      end
    end
  end
end
