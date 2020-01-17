RSpec.describe Metric do
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

  context "as kubernetes" do
    before do
      @ems_kubernetes = FactoryBot.create(:ems_kubernetes, :zone => @zone)

      @node_a = FactoryBot.create(:container_node, :ext_management_system => @ems_kubernetes)
      @node_a.computer_system.hardware = FactoryBot.create(:hardware, :cpu_total_cores => 2)

      @node_b = FactoryBot.create(:container_node, :ext_management_system => @ems_kubernetes)
      @node_b.computer_system.hardware = FactoryBot.create(:hardware, :cpu_total_cores => 8)

      @node_a.metric_rollups << FactoryBot.create(
        :metric_rollup,
        :timestamp                  => rollup_chain_timestamp,
        :cpu_usage_rate_average     => 50.0,
        :capture_interval_name      => 'hourly',
        :derived_vm_numvcpus        => 2,
        :parent_ems_id              => @ems_kubernetes.id
      )

      @node_b.metric_rollups << FactoryBot.create(
        :metric_rollup,
        :timestamp                  => rollup_chain_timestamp,
        :cpu_usage_rate_average     => 75.0,
        :capture_interval_name      => 'hourly',
        :derived_vm_numvcpus        => 8,
        :parent_ems_id              => @ems_kubernetes.id
      )
    end

    let(:rollup_chain_timestamp) { "2011-08-12T20:33:20Z" }

    it "cpu usage rollups should be a weighted average over cores" do
      @ems_kubernetes.perf_rollup(rollup_chain_timestamp, 'hourly')
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
end
