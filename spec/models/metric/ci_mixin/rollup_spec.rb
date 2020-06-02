RSpec.describe Metric::CiMixin::Rollup do
  before do
    MiqRegion.seed

    @zone = miq_server.zone
  end

  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems) { FactoryBot.create(:ems_vmware, :zone => miq_server.zone) }

  describe ".perf_rollup" do
    let(:host) { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true) }
    let(:vm)   { FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host) }
    let(:host2) do
      FactoryBot.create(
        :host_vmware,
        :ext_management_system => ems,
        :perf_capture_enabled  => true,
        :storages              => [storage],
        :ems_cluster           => FactoryBot.create(:ems_cluster, :perf_capture_enabled => true, :ext_management_system => ems)
      )
    end
    let(:vm2)     { FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host2) }
    let(:host3)   { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true) }
    let(:storage) { FactoryBot.create(:storage_vmware, :perf_capture_enabled => true) }
    let(:host4)   { FactoryBot.create(:host_vmware, :ext_management_system => ems, :perf_capture_enabled => true, :ems_cluster => host2.ems_cluster) }

    context "executing capture_ems_targets for realtime targets with parent objects" do
      before do
        stub_settings_merge(:performance => {:history => {:initial_capture_days => 7}})
        vm
        vm2
        host3
        host4
      end

      it "should create tasks and queue callbacks for perf_capture_timer" do
        ems.perf_capture_object.perf_capture_all_queue

        cluster = host2.ems_cluster
        expected_hosts = [host2, host4]

        task = MiqTask.find_by(:name => "Performance rollup for EmsCluster:#{cluster.id}")
        expect(task).not_to be_nil
        expect(task.context_data[:targets]).to match_array(cluster.hosts.collect { |h| "ManageIQ::Providers::Vmware::InfraManager::Host:#{h.id}" })

        expected_hosts.each do |host|
          messages = MiqQueue.where(:class_name  => 'ManageIQ::Providers::Vmware::InfraManager::Host',
                                    :instance_id => host.id,
                                    :method_name => "perf_capture_realtime")
          expect(messages.size).to eq(1)
          messages.each do |m|
            expect(m.miq_task_id).to eq(task.id)
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

      it "calling perf_capture_timer when existing capture messages are on the queue should merge messages and append new task id to cb args" do
        ems.perf_capture_object.perf_capture_all_queue
        ems.perf_capture_object.perf_capture_all_queue

        cluster = host2.ems_cluster
        expected_hosts = [host2, host4]

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
          host.update(:last_perf_capture_on => 1.minute.from_now.utc)
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

      it "calling perf_capture_timer a second time should create another task with the correct time window" do
        ems.perf_capture_object.perf_capture_all_queue
        ems.perf_capture_object.perf_capture_all_queue

        cluster = host2.ems_cluster

        tasks = MiqTask.where(:name => "Performance rollup for EmsCluster:#{cluster.id}").order("id")
        expect(tasks.length).to eq(2)

        t1, t2 = tasks
        expect(t2.context_data[:start]).to eq(t1.context_data[:end])
      end
    end

    context "with Vm realtime performances", :with_small_vmware do
      before do
        cases = {
          "2010-04-14T20:52:30Z" => 100.0,
          "2010-04-14T21:51:10Z" => 1.0,
          "2010-04-14T21:51:30Z" => 2.0,
          "2010-04-14T21:51:50Z" => 4.0,
          "2010-04-14T21:52:10Z" => 8.0,
          "2010-04-14T21:52:30Z" => 15.0,
          "2010-04-14T22:52:30Z" => 100.0,
        }
        cases.each do |t, v|
          @vm1.metrics << FactoryBot.create(
            :metric_vm_rt,
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
          expect(perf.cpu_ready_delta_summation).to eq(30_000.0)
          expect(perf.v_pct_cpu_ready_delta_summation).to eq(30.0)
          expect(perf.sys_uptime_absolute_latest).to eq(15.0)

          expect(perf.abs_max_cpu_usage_rate_average_value).to eq(15.0)
          expect(perf.abs_max_cpu_usage_rate_average_timestamp.utc.iso8601).to eq("2010-04-14T21:52:30Z")

          expect(perf.abs_min_cpu_usage_rate_average_value).to eq(1.0)
          expect(perf.abs_min_cpu_usage_rate_average_timestamp.utc.iso8601).to eq("2010-04-14T21:51:10Z")
        end
      end
    end

    context "with Vm hourly performances", :with_small_vmware do
      before do
        cases = {
          "2010-04-13T21:00:00Z" => 100.0,
          "2010-04-14T18:00:00Z" => 1.0,
          "2010-04-14T19:00:00Z" => 2.0,
          "2010-04-14T20:00:00Z" => 4.0,
          "2010-04-14T21:00:00Z" => 8.0,
          "2010-04-14T22:00:00Z" => 15.0,
          "2010-04-15T21:00:00Z" => 100.0,
        }
        cases.each do |t, v|
          @vm1.metric_rollups << FactoryBot.create(
            :metric_rollup_vm_hr,
            :timestamp                  => t,
            :cpu_usage_rate_average     => v,
            :cpu_ready_delta_summation  => v * 10_000,
            :sys_uptime_absolute_latest => v,
            :min_max                    => {
              :abs_max_cpu_usage_rate_average_value     => v,
              :abs_max_cpu_usage_rate_average_timestamp => Time.parse(t).utc + 20.seconds,
              :abs_min_cpu_usage_rate_average_value     => v,
              :abs_min_cpu_usage_rate_average_timestamp => Time.parse(t).utc + 40.seconds,
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
          expect(perf.cpu_ready_delta_summation).to eq(60_000.0) # actually uses average
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
          expect(perfs.collect { |r| r.timestamp.iso8601 }).to match_array(["2010-04-13T00:00:00Z", "2010-04-14T00:00:00Z", "2010-04-15T00:00:00Z"])
        end
      end

      context "and Host realtime performances" do
        before do
          cases = {
            "2010-04-14T20:52:40Z" => 100.0,
            "2010-04-14T21:51:20Z" => 2.0,
            "2010-04-14T21:51:40Z" => 4.0,
            "2010-04-14T21:52:00Z" => 8.0,
            "2010-04-14T21:52:20Z" => 16.0,
            "2010-04-14T21:52:40Z" => 30.0,
            "2010-04-14T22:52:40Z" => 100.0,
          }
          cases.each do |t, v|
            @host1.metrics << FactoryBot.create(
              :metric_host_rt,
              :timestamp                  => t,
              :cpu_usage_rate_average     => v,
              :cpu_usagemhz_rate_average  => v,
              :sys_uptime_absolute_latest => v
            )
          end

          cases = {
            "2010-04-14T20:52:40Z" => 200.0,
            "2010-04-14T21:51:20Z" => 3.0,
            "2010-04-14T21:51:40Z" => 8.0,
            "2010-04-14T21:52:00Z" => 16.0,
            "2010-04-14T21:52:20Z" => 32.0,
            "2010-04-14T21:52:40Z" => 60.0,
            "2010-04-14T22:52:40Z" => 200.0,
          }
          cases.each do |t, v|
            @host2.metrics << FactoryBot.create(
              :metric_host_rt,
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

            expect(perf.cpu_usage_rate_average).to eq(12.0)         # pulled from Host realtime
            expect(perf.cpu_ready_delta_summation).to eq(80_000.0)  # pulled from Vm hourly
            expect(perf.v_pct_cpu_ready_delta_summation).to eq(2.2)
            expect(perf.sys_uptime_absolute_latest).to eq(30.0)     # pulled from Host realtime

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

            expect(perfs[0].cpu_usage_rate_average).to eq(2.5)     # pulled from Host realtime
            expect(perfs[0].cpu_usagemhz_rate_average).to eq(5.0)  # pulled from Host realtime
            expect(perfs[0].sys_uptime_absolute_latest).to eq(3.0) # pulled from Host realtime
            expect(perfs[0].derived_cpu_available).to eq(19_152)

            expect(perfs[2].cpu_usage_rate_average).to be_within(0.001).of(12.0)     # pulled from Host realtime
            expect(perfs[2].cpu_usagemhz_rate_average).to be_within(0.001).of(24.0)  # pulled from Host realtime
            expect(perfs[2].sys_uptime_absolute_latest).to be_within(0.001).of(16.0) # pulled from Host realtime
            expect(perfs[2].derived_cpu_available).to eq(19_152)

            expect(perfs[3].cpu_usage_rate_average).to be_within(0.001).of(24.0)     # pulled from Host realtime
            expect(perfs[3].cpu_usagemhz_rate_average).to be_within(0.001).of(48.0)  # pulled from Host realtime
            expect(perfs[3].sys_uptime_absolute_latest).to be_within(0.001).of(32.0) # pulled from Host realtime
            expect(perfs[3].derived_cpu_available).to eq(19_152)
          end
        end
      end
    end
  end

  describe "perf_rollup_gap" do
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
          cases = {
            "2010-04-13T21:00:00Z" => 100.0,
            "2010-04-14T18:00:00Z" => 1.0,
            "2010-04-14T19:00:00Z" => 2.0,
            "2010-04-14T20:00:00Z" => 4.0,
            "2010-04-14T21:00:00Z" => 8.0,
            "2010-04-14T22:00:00Z" => 15.0,
            "2010-04-15T21:00:00Z" => 100.0,
          }
          cases.each do |t, v|
            @vm1.metric_rollups << FactoryBot.create(
              :metric_rollup_vm_hr,
              :timestamp                  => t,
              :cpu_usage_rate_average     => v,
              :cpu_ready_delta_summation  => v * 10_000,
              :sys_uptime_absolute_latest => v,
              :min_max                    => {
                :abs_max_cpu_usage_rate_average_value     => v,
                :abs_max_cpu_usage_rate_average_timestamp => Time.parse(t).utc + 20.seconds,
                :abs_min_cpu_usage_rate_average_value     => v,
                :abs_min_cpu_usage_rate_average_timestamp => Time.parse(t).utc + 40.seconds,
              }
            )
          end
        end

        context "and Host realtime performances" do
          before do
            cases = {
              "2010-04-14T20:52:40Z" => 100.0,
              "2010-04-14T21:51:20Z" => 2.0,
              "2010-04-14T21:51:40Z" => 4.0,
              "2010-04-14T21:52:00Z" => 8.0,
              "2010-04-14T21:52:20Z" => 16.0,
              "2010-04-14T21:52:40Z" => 30.0,
              "2010-04-14T22:52:40Z" => 100.0,
            }
            cases.each do |t, v|
              @host1.metrics << FactoryBot.create(
                :metric_host_rt,
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
              @host2.metrics << FactoryBot.create(
                :metric_host_rt,
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
        end
      end
    end
  end

  describe ".perf_rollup_to_parents" do
    context "as vmware" do
      before do
        @ems_vmware = FactoryBot.create(:ems_vmware, :zone => @zone)
        @vm = FactoryBot.create(:vm_perf, :ext_management_system => @ems_vmware)
      end

      it "should have queued rollups for vm hourly" do
        MiqQueue.delete_all
        @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Vmware::InfraManager::Vm")
      end

      it "should have one set of queued rollups when rolled up twice" do
        MiqQueue.delete_all
        @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Vmware::InfraManager::Vm")
      end

      it "queues service rollups" do
        service = FactoryBot.create(:service)
        service.add_resource(@vm)
        service.save
        MiqQueue.delete_all

        @vm.perf_rollup_to_parents("hourly", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")

        expect(MiqQueue.all.pluck(:class_name).uniq).to eq(%w[Service])
      end
    end

    context "with a full vmware rollup chain and time profile" do
      before do
        @ems_vmware = FactoryBot.create(:ems_vmware, :zone => @zone)
        @host = FactoryBot.create(:host, :ext_management_system => @ems_vmware)
        @vm = FactoryBot.create(:vm_vmware, :ext_management_system => @ems_vmware, :host => @host)
        @ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host

        @time_profile = FactoryBot.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      it "should queue up from Vm realtime to Vm hourly" do
        @vm.perf_rollup_to_parents('realtime', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(1)
        assert_queue_item_rollup_chain(q_all[0], @vm, 'hourly')
      end

      it "should queue up from Host realtime to Host hourly" do
        @host.perf_rollup_to_parents('realtime', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(1)
        assert_queue_item_rollup_chain(q_all[0], @host, 'hourly')
      end

      it "should queue up from Vm hourly to Host hourly and Vm daily" do
        @vm.perf_rollup_to_parents('hourly', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_item_rollup_chain(q_all[0], @host, 'hourly')
        assert_queue_item_rollup_chain(q_all[1], @vm,   'daily', @time_profile)
      end

      it "should queue up from Host hourly to EmsCluster hourly and Host daily" do
        @host.perf_rollup_to_parents('hourly', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_item_rollup_chain(q_all[0], @ems_cluster, 'hourly')
        assert_queue_item_rollup_chain(q_all[1], @host,        'daily', @time_profile)
      end

      it "should queue up from EmsCluster hourly to EMS hourly and EmsCluster daily" do
        @ems_cluster.perf_rollup_to_parents('hourly', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_item_rollup_chain(q_all[0], @ems_vmware,  'hourly')
        assert_queue_item_rollup_chain(q_all[1], @ems_cluster, 'daily', @time_profile)
      end

      it "should queue up from Vm daily to nothing" do
        @vm.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end

      it "should queue up from Host daily to nothing" do
        @host.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end

      it "should queue up from EmsCluster daily to nothing" do
        @ems_cluster.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end

      it "should queue up from EMS daily to nothing" do
        @ems_vmware.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end
    end

    context "as openstack" do
      before do
        @ems_openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
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

    context "with a full openstack rollup chain and time profile" do
      before do
        @ems_openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
        @availability_zone = FactoryBot.create(:availability_zone, :ext_management_system => @ems_openstack)
        @vm = FactoryBot.create(:vm_openstack, :ext_management_system => @ems_openstack, :availability_zone => @availability_zone)

        @time_profile = FactoryBot.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      it "should queue up from Vm realtime to Vm hourly" do
        @vm.perf_rollup_to_parents('realtime', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(1)
        assert_queue_item_rollup_chain(q_all[0], @vm, 'hourly')
      end

      it "should queue up from AvailabilityZone realtime to AvailabilityZone hourly" do
        @availability_zone.perf_rollup_to_parents('realtime', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(1)
        assert_queue_item_rollup_chain(q_all[0], @availability_zone, 'hourly')
      end

      it "should queue up from Vm hourly to AvailabilityZone hourly and Vm daily" do
        @vm.perf_rollup_to_parents('hourly', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_item_rollup_chain(q_all[0], @availability_zone, 'hourly')
        assert_queue_item_rollup_chain(q_all[1], @vm, 'daily', @time_profile)
      end

      it "should queue up from AvailabilityZone hourly to EMS hourly and AvailabilityZone daily" do
        @availability_zone.perf_rollup_to_parents('hourly', rollup_chain_timestamp)
        q_all = MiqQueue.order(:id)
        expect(q_all.length).to eq(2)
        assert_queue_item_rollup_chain(q_all[0], @ems_openstack, 'hourly')
        assert_queue_item_rollup_chain(q_all[1], @availability_zone, 'daily', @time_profile)
      end

      it "should queue up from Vm daily to nothing" do
        @vm.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end

      it "should queue up from AvailabilityZone daily to nothing" do
        @availability_zone.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end

      it "should queue up from EMS daily to nothing" do
        @ems_openstack.perf_rollup_to_parents('daily', rollup_chain_timestamp)
        expect(MiqQueue.count).to eq(0)
      end
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

  let(:rollup_chain_timestamp) { "2011-08-12T20:33:20Z" }

  def assert_queue_item_rollup_chain(q_item, obj, interval_name, time_profile = nil)
    case interval_name
    when 'realtime'
      values = [["2011-08-12T20:33:20Z", nil, 'realtime', nil], nil, "perf_rollup_range"]
    when 'hourly'
      values = [["2011-08-12T20:00:00Z", 'hourly'], "2011-08-12T21:00:00Z"]
    when 'daily'
      values = [["2011-08-12T00:00:00Z", 'daily', time_profile.id], "2011-08-13T00:00:00Z"]
    end
    assert_queued_rollup(q_item, obj.id, obj.class.name, *values)
  end
end
