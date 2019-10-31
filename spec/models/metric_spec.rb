describe Metric do
  include Spec::Support::MetricHelper

  before do
    MiqRegion.seed

    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe "metrics view" do
    it "creates an object with an id" do
      metric = described_class.create!(:timestamp => Time.now.utc)
      expect(metric.id).to be > 0
    end

    it "initializes an object's id after save" do
      metric = described_class.new
      metric.timestamp = Time.now.utc
      metric.save!
      expect(metric.id).to be > 0
    end

    it "updates an existing object correctly" do
      metric = described_class.create!(:timestamp => Time.now.utc)
      old_id = metric.id
      metric.update!(:timestamp => Time.now.utc - 1.day)
      expect(metric.id).to eq(old_id)
    end
  end

  context "as vmware" do
    before do
      @ems_vmware = FactoryBot.create(:ems_vmware, :zone => @zone)
    end

    context "with enabled and disabled targets" do
      before do
        storages = FactoryBot.create_list(:storage_target_vmware, 2)
        @vmware_clusters = FactoryBot.create_list(:cluster_target, 2)
        @ems_vmware.ems_clusters = @vmware_clusters

        6.times do |n|
          host = FactoryBot.create(:host_target_vmware, :ext_management_system => @ems_vmware)
          @ems_vmware.hosts << host

          @vmware_clusters[n / 2].hosts << host if n < 4
          host.storages << storages[n / 3]
        end

        MiqQueue.delete_all
      end

      context "executing perf_capture_timer" do
        before do
          stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
          Metric::Capture.perf_capture_timer(@ems_vmware.id)
        end

        let(:expected_queue_items) do
          {
            %w(ManageIQ::Providers::Vmware::InfraManager::Host perf_capture_realtime)   => 3,
            %w(ManageIQ::Providers::Vmware::InfraManager::Host perf_capture_historical) => 24,
            %w(Storage perf_capture_hourly)                                             => 1,
            %w(ManageIQ::Providers::Vmware::InfraManager::Vm perf_capture_realtime)     => 2,
            %w(ManageIQ::Providers::Vmware::InfraManager::Vm perf_capture_historical)   => 16,
            %w(MiqTask destroy_older_by_condition)                                      => 1
          }
        end

        it "should queue up enabled targets" do
          expect(MiqQueue.group(:class_name, :method_name).count).to eq(expected_queue_items)
          assert_metric_targets(Metric::Targets.capture_ems_targets(@ems_vmware.reload))
        end

        context "executing capture_ems_targets for realtime targets with parent objects" do
          before do
            @expected_targets = Metric::Targets.capture_ems_targets(@ems_vmware)
          end

          it "should create tasks and queue callbacks" do
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

          it "calling perf_capture_timer when existing capture messages are on the queue in dequeue state should NOT merge" do
            messages = MiqQueue.where(:class_name => "Host", :method_name => 'capture_metrics_realtime')
            messages.each { |m| m.update_attribute(:state, "dequeue") }

            Metric::Capture.perf_capture_timer(@ems_vmware.id)

            messages = MiqQueue.where(:class_name => "Host", :method_name => 'capture_metrics_realtime')
            messages.each { |m| expect(m.lock_version).to eq(1) }
          end

          it "calling perf_capture_timer a second time should create another task with the correct time window" do
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

      context "executing perf_capture_gap" do
        before do
          t = Time.now.utc
          Metric::Capture.perf_capture_gap(t - 7.days, t - 5.days)
        end

        it "should queue up enabled targets for historical" do
          expect(MiqQueue.count).to eq(10)

          expected_targets = Metric::Targets.capture_ems_targets(@ems_vmware.reload, :exclude_storages => true)
          expected = expected_targets.flat_map { |t| [[t, "historical"]] * 2 } # Vm, Host, Host, Vm, Host

          selected = queue_intervals(MiqQueue.all)

          expect(selected).to match_array(expected)
        end
      end

      context "executing perf_capture_realtime_now" do
        before do
          @vm = Vm.first
          @vm.perf_capture_realtime_now
        end

        it "should queue up realtime capture for vm" do
          expect(MiqQueue.count).to eq(1)

          msg = MiqQueue.first
          expect(msg.priority).to eq(MiqQueue::HIGH_PRIORITY)
          expect(msg.instance_id).to eq(@vm.id)
          expect(msg.class_name).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
        end

        context "with an existing queue item at a lower priority" do
          before do
            MiqQueue.first.update_attribute(:priority, MiqQueue::NORMAL_PRIORITY)
            @vm.perf_capture_realtime_now
          end

          it "should raise the priority of the existing queue item" do
            expect(MiqQueue.count).to eq(1)

            msg = MiqQueue.first
            expect(msg.priority).to eq(MiqQueue::HIGH_PRIORITY)
            expect(msg.instance_id).to eq(@vm.id)
            expect(msg.class_name).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
          end
        end

        context "with an existing queue item at a higher priority" do
          before do
            MiqQueue.first.update_attribute(:priority, MiqQueue::MAX_PRIORITY)
            @vm.perf_capture_realtime_now
          end

          it "should not lower the priority of the existing queue item" do
            expect(MiqQueue.count).to eq(1)

            msg = MiqQueue.first
            expect(msg.priority).to eq(MiqQueue::MAX_PRIORITY)
            expect(msg.instance_id).to eq(@vm.id)
            expect(msg.class_name).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
          end
        end
      end
    end

    context "with a vm" do
      before do
        @vm = FactoryBot.create(:vm_perf, :ext_management_system => @ems_vmware)
      end

      context "queueing up realtime rollups to parent" do
        before do
          MiqQueue.delete_all
          @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        end

        it "should have queued rollups for vm hourly" do
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Vmware::InfraManager::Vm")
        end

        context "twice" do
          before do
            @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
          end

          it "should have one set of queued rollups" do
            q_all = MiqQueue.order(:id)
            expect(q_all.length).to eq(2)
            assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Vmware::InfraManager::Vm")
          end
        end
      end

      context "services" do
        let(:service) { FactoryBot.create(:service) }

        before do
          service.add_resource(@vm)
          service.save
          MiqQueue.delete_all
        end

        it "queues service rollups" do
          @vm.perf_rollup_to_parents("hourly", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")

          expect(MiqQueue.all.pluck(:class_name).uniq).to eq(%w(Service))
        end
      end
    end

    context "with a small environment and time_profile" do
      before do
        @vm1 = FactoryBot.create(:vm_vmware)
        @vm2 = FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :cpu1x2, :memory_mb => 4096))
        @host1 = FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
        @host2 = FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576))

        @ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host1
        @ems_cluster.hosts << @host2

        @time_profile = FactoryBot.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "with Vm hourly performances" do
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

          context "executing perf_rollup_gap_queue" do
            before do
              @args = [2.days.ago.utc, Time.now.utc, 'daily', @time_profile.id]
              Metric::Rollup.perf_rollup_gap_queue(*@args)
            end

            it "should queue up perf_rollup_gap" do
              q_all = MiqQueue.order(:class_name)
              expect(q_all.length).to eq(1)

              expected = {
                :args        => @args,
                :class_name  => "Metric::Rollup",
                :method_name => "perf_rollup_gap",
                :role        => nil
              }

              expect(q_all[0]).to have_attributes(expected)
            end
          end

          context "executing perf_rollup_gap" do
            before do
              @args = [2.days.ago.utc, Time.now.utc, 'daily', @time_profile.id]
              Metric::Rollup.perf_rollup_gap(*@args)
            end

            it "should queue up the rollups" do
              expect(MiqQueue.count).to eq(3)

              [@host1, @host2, @vm1].each do |ci|
                message = MiqQueue.where(:class_name => ci.class.name, :instance_id => ci.id).first
                expect(message).to have_attributes(:method_name => "perf_rollup_range", :args => @args)
              end
            end
          end

          context "calling get_performance_metric" do
            it "should return the correct value(s)" do
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"])).to eq([100.0, 2.0, 4.0, 8.0, 16.0, 30.0, 100.0])
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"], :avg)).to be_within(0.0001).of(37.1428571428571)
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"], :min)).to eq(2.0)
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"], :max)).to eq(100.0)

              # Test supported formats of time range
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z".to_time(:utc), "2010-04-14T22:52:40Z".to_time(:utc)], :min)).to eq(2.0)
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, "2010-04-14T20:52:40Z", :max)).to eq(100.0)
              expect(@host1.get_performance_metric(:realtime, :cpu_usage_rate_average, "2010-04-14T20:52:40Z".to_time(:utc), :max)).to eq(100.0)
            end
          end
        end
      end

      context "#generate_vim_performance_operating_range" do
        before do
          Timecop.travel(Time.parse("2010-05-01T00:00:00Z"))
          cases = [
            "2010-04-01T00:00:00Z",  9.14, 32.85,
            "2010-04-13T21:00:00Z",  9.14, 32.85,
            "2010-04-14T18:00:00Z", 10.23, 28.76,
            "2010-04-14T19:00:00Z", 18.92, 39.11,
            "2010-04-14T20:00:00Z",  7.34, 28.87,
            "2010-04-14T21:00:00Z",  8.00, 29.99,
            "2010-04-14T22:00:00Z", 15.00, 41.59,
            "2010-04-15T21:00:00Z", 27.22, 30.43,
          ]
          cases.each_slice(3) do |t, cpu, mem|
            [@vm1, @vm2].each do |vm|
              vm.metric_rollups << FactoryBot.create(:metric_rollup_vm_daily,
                                                      :timestamp                  => t,
                                                      :cpu_usage_rate_average     => cpu,
                                                      :mem_usage_absolute_average => mem,
                                                      :min_max                    => {
                                                        :max_cpu_usage_rate_average     => cpu,
                                                        :max_mem_usage_absolute_average => mem,
                                                      },
                                                      :time_profile               => @time_profile
                                                     )
            end
          end
        end

        after do
          Timecop.return
        end

        it "should calculate the correct normal operating range values" do
          @vm1.generate_vim_performance_operating_range(@time_profile)

          expect(@vm1.max_cpu_usage_rate_average_avg_over_time_period).to     be_within(0.001).of(13.124)
          expect(@vm1.max_mem_usage_absolute_average_avg_over_time_period).to be_within(0.001).of(33.056)

          expect(@vm1.cpu_usage_rate_average_avg_over_time_period).to         be_within(0.001).of(13.124)
          expect(@vm1.cpu_usage_rate_average_high_over_time_period).to        be_within(0.001).of(20.048)
          expect(@vm1.cpu_usage_rate_average_low_over_time_period).to         be_within(0.001).of(6.199)
          expect(@vm1.mem_usage_absolute_average_avg_over_time_period).to     be_within(0.001).of(33.056)
          expect(@vm1.mem_usage_absolute_average_high_over_time_period).to    be_within(0.001).of(37.865)
          expect(@vm1.mem_usage_absolute_average_low_over_time_period).to     be_within(0.001).of(28.248)
        end

        it "should calculate the correct right-size values" do
          allow(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:mem_recommendation_minimum).and_return(0)

          @vm1.generate_vim_performance_operating_range(@time_profile)
          @vm2.generate_vim_performance_operating_range(@time_profile)

          expect(@vm1.recommended_vcpus).to eq(1)
          expect(@vm1.recommended_mem).to eq(4)
          expect(@vm1.overallocated_vcpus_pct).to eq(0)
          expect(@vm1.overallocated_mem_pct).to eq(0)

          expect(@vm2.recommended_vcpus).to eq(1)
          expect(@vm2.recommended_mem).to eq(1356)
          expect(@vm2.overallocated_vcpus_pct).to be_within(0.01).of(50.0)
          expect(@vm2.overallocated_mem_pct).to   be_within(0.01).of(66.9)
        end
      end
    end

    context "with a full rollup chain and time profile" do
      before do
        @host = FactoryBot.create(:host, :ext_management_system => @ems_vmware)
        @vm = FactoryBot.create(:vm_vmware, :ext_management_system => @ems_vmware, :host => @host)
        @ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host

        @time_profile = FactoryBot.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "calling perf_rollup_to_parents" do
        it "should queue up from Vm realtime to Vm hourly" do
          @vm.perf_rollup_to_parents('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(1)
          assert_queue_item_rollup_chain(q_all[0], @vm, 'hourly')
        end

        it "should queue up from Host realtime to Host hourly" do
          @host.perf_rollup_to_parents('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(1)
          assert_queue_item_rollup_chain(q_all[0], @host, 'hourly')
        end

        it "should queue up from Vm hourly to Host hourly and Vm daily" do
          @vm.perf_rollup_to_parents('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_item_rollup_chain(q_all[0], @host, 'hourly')
          assert_queue_item_rollup_chain(q_all[1], @vm,   'daily', @time_profile)
        end

        it "should queue up from Host hourly to EmsCluster hourly and Host daily" do
          @host.perf_rollup_to_parents('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_item_rollup_chain(q_all[0], @ems_cluster, 'hourly')
          assert_queue_item_rollup_chain(q_all[1], @host,        'daily', @time_profile)
        end

        it "should queue up from EmsCluster hourly to EMS hourly and EmsCluster daily" do
          @ems_cluster.perf_rollup_to_parents('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_item_rollup_chain(q_all[0], @ems_vmware,         'hourly')
          assert_queue_item_rollup_chain(q_all[1], @ems_cluster, 'daily', @time_profile)
        end

        it "should queue up from Vm daily to nothing" do
          @vm.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end

        it "should queue up from Host daily to nothing" do
          @host.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end

        it "should queue up from EmsCluster daily to nothing" do
          @ems_cluster.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end

        it "should queue up from EMS daily to nothing" do
          @ems_vmware.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end
      end
    end

    context "Testing CPU % virtual cols with existing performance data" do
      it "should return the correct values for Vm realtime" do
        pdata = {
          :resource_type             => "VmOrTemplate",
          :capture_interval_name     => "realtime",
          :cpu_ready_delta_summation => 1060.0,
          :cpu_used_delta_summation  => 4012.0,
          :cpu_wait_delta_summation  => 27090.0,
        }
        perf = Metric.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(5.3)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(20.1)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(135.5)
      end
    end

    context "with a cluster" do
      context "maintains_value_for_duration?" do
        it "should handle the only event right before the starting on time (FB15770)" do
          @ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => @ems_vmware)
          @ems_cluster.metric_rollups << FactoryBot.create(:metric_rollup_vm_hr,
                                                            :timestamp => Time.parse("2011-08-12T20:33:12Z")
                                                           )

          options = {:debug_trace     => "false",
                     :value           => "50",
                     :operator        => ">",
                     :duration        => 3600,
                     :column          => "v_pct_cpu_ready_delta_summation",
                     :interval_name   => "hourly",
                     :starting_on     => Time.parse("2011-08-12T20:33:20Z"),
                     :trend_direction => "none"
          }
          expect(@ems_cluster.performances_maintains_value_for_duration?(options)).to eq(false)
        end
      end
    end
  end

  context "as openstack" do
    before do
      @ems_openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
    end

    context "with enabled and disabled targets" do
      before do
        @availability_zone = FactoryBot.create(:availability_zone_target)
        @ems_openstack.availability_zones << @availability_zone
        @vms_in_az = FactoryBot.create_list(:vm_openstack, 2, :ems_id => @ems_openstack.id)
        @availability_zone.vms = @vms_in_az
        @availability_zone.vms.push(FactoryBot.create(:vm_openstack, :ems_id => nil))
        @vms_not_in_az = FactoryBot.create_list(:vm_openstack, 3, :ems_id => @ems_openstack.id)

        MiqQueue.delete_all
      end

      context "executing perf_capture_timer" do
        before do
          stub_settings(:performance => {:history => {:initial_capture_days => 7}})
          Metric::Capture.perf_capture_timer(@ems_openstack.id)
        end

        it "should queue up enabled targets" do
          expected_targets = Metric::Targets.capture_ems_targets(@ems_openstack)
          expect(MiqQueue.group(:method_name).count).to eq('perf_capture_realtime'      => expected_targets.count,
                                                           'perf_capture_historical'    => expected_targets.count * 8,
                                                           'destroy_older_by_condition' => 1)
          assert_metric_targets(expected_targets)
        end
      end
    end

    context "with a vm" do
      before do
        @vm = FactoryBot.create(:vm_perf_openstack, :ext_management_system => @ems_openstack)
      end

      context "queueing up realtime rollups to parent" do
        before do
          MiqQueue.delete_all
          @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        end

        it "should have queued rollups for vm hourly" do
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Openstack::CloudManager::Vm")
        end

        context "twice" do
          before do
            @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
          end

          it "should have one set of queued rollups" do
            q_all = MiqQueue.order(:id)
            expect(q_all.length).to eq(2)
            assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Openstack::CloudManager::Vm")
          end
        end
      end
    end

    context "with a full rollup chain and time profile" do
      before do
        @availability_zone = FactoryBot.create(:availability_zone, :ext_management_system => @ems_openstack)
        @vm = FactoryBot.create(:vm_openstack, :ext_management_system => @ems_openstack, :availability_zone => @availability_zone)

        @time_profile = FactoryBot.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "calling perf_rollup_to_parents" do
        it "should queue up from Vm realtime to Vm hourly" do
          @vm.perf_rollup_to_parents('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(1)
          assert_queue_item_rollup_chain(q_all[0], @vm, 'hourly')
        end

        it "should queue up from AvailabilityZone realtime to AvailabilityZone hourly" do
          @availability_zone.perf_rollup_to_parents('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(1)
          assert_queue_item_rollup_chain(q_all[0], @availability_zone, 'hourly')
        end

        it "should queue up from Vm hourly to AvailabilityZone hourly and Vm daily" do
          @vm.perf_rollup_to_parents('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_item_rollup_chain(q_all[0], @availability_zone, 'hourly')
          assert_queue_item_rollup_chain(q_all[1], @vm,   'daily', @time_profile)
        end

        it "should queue up from AvailabilityZone hourly to EMS hourly and AvailabilityZone daily" do
          @availability_zone.perf_rollup_to_parents('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_item_rollup_chain(q_all[0], @ems_openstack,  'hourly')
          assert_queue_item_rollup_chain(q_all[1], @availability_zone, 'daily', @time_profile)
        end

        it "should queue up from Vm daily to nothing" do
          @vm.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end

        it "should queue up from AvailabilityZone daily to nothing" do
          @availability_zone.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end

        it "should queue up from EMS daily to nothing" do
          @ems_openstack.perf_rollup_to_parents('daily', ROLLUP_CHAIN_TIMESTAMP)
          expect(MiqQueue.count).to eq(0)
        end
      end
    end
  end

  context "as kubernetes" do
    before do
      @ems_kubernetes = FactoryBot.create(:ems_kubernetes, :zone => @zone)

      @node_a = FactoryBot.create(:container_node, :ext_management_system => @ems_kubernetes)
      @node_a.computer_system.hardware = FactoryBot.create(:hardware, :cpu_total_cores => 2)

      @node_b = FactoryBot.create(:container_node, :ext_management_system => @ems_kubernetes)
      @node_b.computer_system.hardware = FactoryBot.create(:hardware, :cpu_total_cores => 8)

      @node_a.metric_rollups << FactoryBot.create(
        :metric_rollup,
        :timestamp                  => ROLLUP_CHAIN_TIMESTAMP,
        :cpu_usage_rate_average     => 50.0,
        :capture_interval_name      => 'hourly',
        :derived_vm_numvcpus        => 2,
        :parent_ems_id              => @ems_kubernetes.id
      )

      @node_b.metric_rollups << FactoryBot.create(
        :metric_rollup,
        :timestamp                  => ROLLUP_CHAIN_TIMESTAMP,
        :cpu_usage_rate_average     => 75.0,
        :capture_interval_name      => 'hourly',
        :derived_vm_numvcpus        => 8,
        :parent_ems_id              => @ems_kubernetes.id
      )
    end

    it "cpu usage rollups should be a weighted average over cores" do
      @ems_kubernetes.perf_rollup(ROLLUP_CHAIN_TIMESTAMP, 'hourly')
      ems_rollup = @ems_kubernetes.metric_rollups.first

      expect(ems_rollup.derived_vm_numvcpus).to eq(10.0)

      # NOTE: The expected cpu_usage_rate_average must be a weighted average
      # over number of cores. In fact an 8 cores node (as in this example)
      # with 75% usage can be compared and aggregated with a 2 cores only
      # after being normalized.
      #
      # In fact:
      #
      #   50% of 2 cores system ~ 1 core in use
      #   75% of 8 cores system ~ 6 cores in use
      #
      # Total: 10 cores and 7 in use => 70% usage
      #
      # *NOT*
      #
      #   average of 50% and 75% = 87.5%
      #
      # 87.5% of 10 cores => 8.75 cores in use (WRONG)
      #
      expect(ems_rollup.cpu_usage_rate_average).to eq(70.0)
      expect(ems_rollup.v_derived_cpu_total_cores_used).to eq(7.0)
    end
  end

  context "#reindex_table_name" do
    it "defaults to 1 hour from now" do
      Timecop.freeze("2017-01-30T09:20UTC") do
        expect(Metric.reindex_table_name).to eq("metrics_10")
      end
    end

    it "pads table to 2 digits" do
      Timecop.freeze("2017-01-30T03:20UTC") do
        expect(Metric.reindex_table_name).to eq("metrics_04")
      end
    end

    it "provides hour wrap around" do
      Timecop.freeze("2017-01-30T23:20UTC") do
        expect(Metric.reindex_table_name).to eq("metrics_00")
      end
    end

    it "allows time to be passed in" do
      expect(Metric.reindex_table_name(Time.parse("2017-01-30T23:20Z").utc)).to eq("metrics_23")
    end

    it "allows hour integer to be passed in" do
      expect(Metric.reindex_table_name(23)).to eq("metrics_23")
    end
  end

  private

  def assert_queued_rollup(q_item, instance_id, class_name, args, deliver_on, method = "perf_rollup")
    deliver_on = Time.parse(deliver_on).utc if deliver_on.kind_of?(String)

    expect(q_item.method_name).to eq(method)
    expect(q_item.instance_id).to eq(instance_id)
    expect(q_item.class_name).to eq(class_name)
    expect(q_item.args).to eq(args)
    expect(q_item.deliver_on.utc).to eq(deliver_on) unless deliver_on.nil?
  end

  def assert_queue_items_are_hourly_rollups(q_items, first_time, instance_id, class_name)
    ts = first_time.kind_of?(Time) ? first_time.utc.iso8601 : first_time
    q_items.each do |q|
      assert_queued_rollup(q, instance_id, class_name, [ts, "hourly"], Time.parse(ts).utc + 1.hour)
      ts = (Time.parse(ts).utc + 1.hour).iso8601
    end
  end

  ROLLUP_CHAIN_TIMESTAMP       = "2011-08-12T20:33:20Z"
  ROLLUP_CHAIN_REALTIME_VALUES = [["2011-08-12T20:33:20Z", nil, 'realtime', nil], nil, "perf_rollup_range"]
  ROLLUP_CHAIN_HOURLY_VALUES   = [["2011-08-12T20:00:00Z", 'hourly'], "2011-08-12T21:00:00Z"]
  ROLLUP_CHAIN_DAILY_VALUES    = [["2011-08-12T00:00:00Z", 'daily', nil], "2011-08-13T00:00:00Z"] # nil will be filled in later during test

  def assert_queue_item_rollup_chain(q_item, obj, interval_name, time_profile = nil)
    case interval_name
    when 'realtime'
      values = ROLLUP_CHAIN_REALTIME_VALUES
    when 'hourly'
      values = ROLLUP_CHAIN_HOURLY_VALUES
    when 'daily'
      values = ROLLUP_CHAIN_DAILY_VALUES
      values[0][2] = time_profile.id
    end
    assert_queued_rollup(q_item, obj.id, obj.class.name, *values)
  end
end
