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
