describe Metric do
  before(:each) do
    MiqRegion.seed
    @zone = EvmSpecHelper.local_miq_server.zone
  end

  context "as vmware" do
    before :each do
      @ems_vmware = FactoryGirl.create(:ems_vmware, :zone => @zone)
    end

    context "with a vm" do
      before(:each) do
        @vm = FactoryGirl.create(:vm_perf, :ext_management_system => @ems_vmware)
      end

      context "queueing up realtime rollups to parent" do
        before(:each) do
          MiqQueue.delete_all
          @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        end

        it "should have queued rollups for vm hourly" do
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Vmware::InfraManager::Vm")
        end

        context "twice" do
          before(:each) do
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
        let(:service) { FactoryGirl.create(:service) }

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
      before(:each) do
        @vm1 = FactoryGirl.create(:vm_vmware)
        @vm2 = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :cpu1x2, :memory_mb => 4096))
        @host1 = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
        @host2 = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576))

        @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host1
        @ems_cluster.hosts << @host2

        @time_profile = FactoryGirl.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "with Vm realtime performances" do
        before(:each) do
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
            @vm1.metrics << FactoryGirl.create(:metric_vm_rt,
                                               :timestamp                  => t,
                                               :cpu_usage_rate_average     => v,
                                               :cpu_ready_delta_summation  => v * 1000, # Multiply by a factor of 1000 to maake it more realistic and enable testing virtual col v_pct_cpu_ready_delta_summation
                                               :sys_uptime_absolute_latest => v
                                              )
          end
        end

        it "should find the correct rows" do
          expect(Metric::Finders.hour_to_range("2010-04-14T21:00:00Z")).to eq(["2010-04-14T21:00:00Z", "2010-04-14T21:59:59Z"])
          expect(Metric::Finders.find_all_by_hour(@vm1, "2010-04-14T21:00:00Z", 'realtime')).to match_array @vm1.metrics.sort_by(&:timestamp)[1..5]
        end

        context "calling perf_rollup to hourly on the Vm" do
          before(:each) do
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

      context "with Vm hourly performances" do
        before(:each) do
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
            @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
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

        it "should find the correct rows" do
          expect(Metric::Finders.day_to_range("2010-04-14T00:00:00Z", @time_profile)).to eq(["2010-04-14T00:00:00Z", "2010-04-14T23:59:59Z"])
          expect(Metric::Finders.find_all_by_day(@vm1, "2010-04-14T00:00:00Z", 'hourly', @time_profile)).to match_array @vm1.metric_rollups.sort_by(&:timestamp)[1..5]
        end

        it "should find multiple resource types" do
          @host1.metric_rollups << FactoryGirl.create(:metric_rollup_host_hr,
                                                      :resource  => @host1,
                                                      :timestamp => "2010-04-14T22:00:00Z")
          metrics = Metric::Finders.find_all_by_day([@vm1, @host1], "2010-04-14T00:00:00Z", 'hourly', @time_profile)
          expect(metrics.collect(&:resource_type).uniq).to match_array(%w(VmOrTemplate Host))
        end

        context "calling perf_rollup to daily on the Vm" do
          before(:each) do
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
          before(:each) do
            @vm1.perf_rollup_range("2010-04-13T00:00:00Z", "2010-04-15T00:00:00Z", 'daily', @time_profile.id)
          end

          it "should rollup Vm hourly into Vm daily rows correctly" do
            perfs = MetricRollup.daily
            expect(perfs.length).to eq(3)
            expect(perfs.collect { |r| r.timestamp.iso8601 }).to match_array(
              ["2010-04-13T00:00:00Z", "2010-04-14T00:00:00Z", "2010-04-15T00:00:00Z"])
          end
        end

        context "with Vm daily performances" do
          before(:each) do
            @perf = FactoryGirl.create(:metric_rollup_vm_daily,
                                       :timestamp    => "2010-04-14T00:00:00Z",
                                       :time_profile => @time_profile
                                      )
          end

          it "VimPerformanceDaily.find should return existing daily performances when a time_profile is passed" do
            rec = Metric::Helper.find_for_interval_name("daily", @time_profile)
            expect(rec).to eq([@perf])
          end

          it "VimPerformanceDaily.find should return existing daily performances when a time_profile is not passed, but an associated tz is" do
            rec = Metric::Helper.find_for_interval_name("daily", "UTC")
            expect(rec).to eq([@perf])
          end

          it "VimPerformanceDaily.find should return existing daily performances when defaulting to UTC time zone" do
            rec = Metric::Helper.find_for_interval_name("daily")
            expect(rec).to eq([@perf])
          end

          it "VimPerformanceDaily.find should return an empty array when a time_profile is not passed" do
            rec = Metric::Helper.find_for_interval_name("daily", "Alaska")
            expect(rec.length).to eq(0)
          end
        end

        context "and Host realtime performances" do
          before(:each) do
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
              @host1.metrics << FactoryGirl.create(:metric_host_rt,
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
              @host2.metrics << FactoryGirl.create(:metric_host_rt,
                                                   :timestamp                  => t,
                                                   :cpu_usage_rate_average     => v,
                                                   :cpu_usagemhz_rate_average  => v,
                                                   :sys_uptime_absolute_latest => v
                                                  )
            end
          end

          context "calling perf_rollup to hourly on the Host" do
            before(:each) do
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
            before(:each) do
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

          context "executing perf_rollup_gap_queue" do
            before(:each) do
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
            before(:each) do
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
              vm.metric_rollups << FactoryGirl.create(:metric_rollup_vm_daily,
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

          expect(@vm1.max_cpu_usage_rate_average_avg_over_time_period).to     be_within(0.001).of(13.692)
          expect(@vm1.max_mem_usage_absolute_average_avg_over_time_period).to be_within(0.001).of(33.085)
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
      before(:each) do
        @host = FactoryGirl.create(:host, :ext_management_system => @ems_vmware)
        @vm = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems_vmware, :host => @host)
        @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host

        @time_profile = FactoryGirl.create(:time_profile_utc)

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

    context ".day_to_range" do
      it "should return the correct start and end dates when calling day_to_range before DST starts" do
        s, e = Metric::Finders.day_to_range("2011-03-12T05:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
        expect(s).to eq('2011-03-12T05:00:00Z')
        expect(e).to eq('2011-03-13T04:59:59Z')
      end

      it "should return the correct start and end dates when calling day_to_range on the day DST starts" do
        s, e = Metric::Finders.day_to_range("2011-03-13T05:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
        expect(s).to eq('2011-03-13T05:00:00Z')
        expect(e).to eq('2011-03-14T03:59:59Z')
      end

      it "should return the correct start and end dates when calling day_to_range after DST starts" do
        s, e = Metric::Finders.day_to_range("2011-03-14T04:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
        expect(s).to eq('2011-03-14T04:00:00Z')
        expect(e).to eq('2011-03-15T03:59:59Z')
      end
    end

    context ".days_from_range" do
      it "should return the correct dates and times when calling days_from_range before DST starts" do
        days = Metric::Helper.days_from_range('2011-03-01T15:24:00Z', '2011-03-03T13:45:00Z', "Eastern Time (US & Canada)")
        expect(days).to eq(["2011-03-01T05:00:00Z", "2011-03-02T05:00:00Z", "2011-03-03T05:00:00Z"])
      end

      it "should return the correct dates and times when calling days_from_range when start and end dates span DST" do
        days = Metric::Helper.days_from_range('2011-03-12T11:23:00Z', '2011-03-14T14:33:00Z', "Eastern Time (US & Canada)")
        expect(days).to eq(["2011-03-12T05:00:00Z", "2011-03-13T05:00:00Z", "2011-03-14T04:00:00Z"])
      end

      it "should return the correct dates and times when calling days_from_range before DST starts" do
        days = Metric::Helper.days_from_range('2011-03-15T17:22:00Z', '2011-03-17T19:52:00Z', "Eastern Time (US & Canada)")
        expect(days).to eq(["2011-03-15T04:00:00Z", "2011-03-16T04:00:00Z", "2011-03-17T04:00:00Z"])
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

      it "should return the correct values for Vm hourly" do
        pdata = {
          :resource_type             => "VmOrTemplate",
          :capture_interval_name     => "hourly",
          :intervals_in_rollup       => 180,
          :cpu_ready_delta_summation => 10604.0,
          :cpu_used_delta_summation  => 401296.0,
          :cpu_wait_delta_summation  => 6709070.0,
        }
        perf = MetricRollup.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.3)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(11.1)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(186.4)
      end

      it "should return the correct values for Vm daily" do
        pdata = {
          :resource_type             => "VmOrTemplate",
          :capture_interval_name     => "daily",
          :intervals_in_rollup       => 24,
          :cpu_ready_delta_summation => 10868.0833333333,
          :cpu_used_delta_summation  => 131611.583333333,
          :cpu_wait_delta_summation  => 6772579.45833333,
        }
        perf = MetricRollup.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.3)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(3.7)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(188.1)
      end

      it "should return the correct values for Host hourly" do
        pdata = {
          :resource_type             => "Host",
          :capture_interval_name     => "hourly",
          :intervals_in_rollup       => 179,
          :derived_vm_count_on       => 6,
          :cpu_ready_delta_summation => 54281.0,
          :cpu_used_delta_summation  => 2324833.0,
          :cpu_wait_delta_summation  => 36722174.0,
        }
        perf = MetricRollup.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.3)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(10.8)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(170.0)

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
      end

      it "should return the correct values for Host daily" do
        pdata = {
          :resource_type             => "Host",
          :capture_interval_name     => "daily",
          :intervals_in_rollup       => 24,
          :derived_vm_count_on       => 6,
          :cpu_ready_delta_summation => 50579.1666666667,
          :cpu_used_delta_summation  => 2180869.375,
          :cpu_wait_delta_summation  => 36918805.4166667,
        }
        perf = MetricRollup.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.2)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(10.1)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(170.9)

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
      end

      it "should return the correct values for Cluster hourly" do
        pdata = {
          :resource_type             => "EmsCluster",
          :capture_interval_name     => "hourly",
          :intervals_in_rollup       => nil,
          :derived_vm_count_on       => 10,
          :cpu_ready_delta_summation => 58783.0,
          :cpu_used_delta_summation  => 3668409.0,
          :cpu_wait_delta_summation  => 60426340.0,
        }
        perf = MetricRollup.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.2)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(10.2)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(167.9)

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
      end

      it "should return the correct values for Cluster daily" do
        pdata = {
          :resource_type             => "EmsCluster",
          :capture_interval_name     => "daily",
          :intervals_in_rollup       => 24,
          :derived_vm_count_on       => 10,
          :cpu_ready_delta_summation => 54120.0833333333,
          :cpu_used_delta_summation  => 3209660.54166667,
          :cpu_wait_delta_summation  => 60868270.1666667,
        }
        perf = MetricRollup.new(pdata)

        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.2)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(8.9)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(169.1)

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
        expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
      end
    end

    context "with a cluster" do
      context "maintains_value_for_duration?" do
        it "should handle the only event right before the starting on time (FB15770)" do
          @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems_vmware)
          @ems_cluster.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
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
    before :each do
      @ems_openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
    end

    context "with a vm" do
      before(:each) do
        @vm = FactoryGirl.create(:vm_perf_openstack, :ext_management_system => @ems_openstack)
      end

      context "queueing up realtime rollups to parent" do
        before(:each) do
          MiqQueue.delete_all
          @vm.perf_rollup_to_parents("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        end

        it "should have queued rollups for vm hourly" do
          q_all = MiqQueue.order(:id)
          expect(q_all.length).to eq(2)
          assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "ManageIQ::Providers::Openstack::CloudManager::Vm")
        end

        context "twice" do
          before(:each) do
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
      before(:each) do
        @availability_zone = FactoryGirl.create(:availability_zone, :ext_management_system => @ems_openstack)
        @vm = FactoryGirl.create(:vm_openstack, :ext_management_system => @ems_openstack, :availability_zone => @availability_zone)

        @time_profile = FactoryGirl.create(:time_profile_utc)

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
      @ems_kubernetes = FactoryGirl.create(:ems_kubernetes, :zone => @zone)

      @node_a = FactoryGirl.create(:container_node, :ext_management_system => @ems_kubernetes)
      @node_a.computer_system.hardware = FactoryGirl.create(:hardware, :cpu_total_cores => 2)

      @node_b = FactoryGirl.create(:container_node, :ext_management_system => @ems_kubernetes)
      @node_b.computer_system.hardware = FactoryGirl.create(:hardware, :cpu_total_cores => 8)

      @node_a.metric_rollups << FactoryGirl.create(
        :metric_rollup,
        :timestamp                  => ROLLUP_CHAIN_TIMESTAMP,
        :cpu_usage_rate_average     => 50.0,
        :capture_interval_name      => 'hourly',
        :derived_vm_numvcpus        => 2,
        :parent_ems_id              => @ems_kubernetes.id
      )

      @node_b.metric_rollups << FactoryGirl.create(
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

  def assert_infra_targets_enabled(targets, expected_types)
    # infra only
    selected_types = []
    targets.each do |t|
      selected_types << t.class.name

      expected_enabled = case t
                         when Vm then      t.host.perf_capture_enabled?
                         when Host then    t.perf_capture_enabled? || t.ems_cluster.perf_capture_enabled?
                         when Storage then t.perf_capture_enabled?
                         end
      expect(expected_enabled).to be_truthy
    end

    expect(selected_types).to match_array(expected_types)
  end

  def assert_cloud_targets_enabled(targets, expected_types)
    selected_types = []
    targets.each do |t|
      selected_types << t.class.name

      expected_enabled = case t
                         # Vm's perf_capture_enabled? is its availability_zone's perf_capture setting,
                         #   or true if it has no availability_zone
                         when Vm then                t.availability_zone ? t.availability_zone.perf_capture_enabled? : true
                         when AvailabilityZone then  t.perf_capture_enabled?
                         when Storage then           t.perf_capture_enabled?
                         end
      expect(expected_enabled).to be_truthy
    end

    expect(selected_types).to match_array(expected_types)
  end
end
