describe ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture do
  before do
    @ems_kubernetes = FactoryGirl.create(:ems_kubernetes)

    @node = FactoryGirl.create(:kubernetes_node,
                               :name                  => 'node',
                               :ext_management_system => @ems_kubernetes,
                               :ems_ref               => 'target')

    @node.computer_system.hardware = FactoryGirl.create(
      :hardware,
      :cpu_total_cores => 2,
      :memory_mb       => 2048)

    @group = FactoryGirl.create(:container_group,
                                :ext_management_system => @ems_kubernetes,
                                :container_node        => @node,
                                :ems_ref               => 'group')

    @container = FactoryGirl.create(:kubernetes_container,
                                    :name                  => 'container',
                                    :container_group       => @group,
                                    :ext_management_system => @ems_kubernetes,
                                    :ems_ref               => 'target')
  end

  context "#perf_collect_metrics" do
    it "raises an error when no ems is defined" do
      @node.ext_management_system = nil
      expect { @node.perf_collect_metrics('interval_name') }.to raise_error(
        described_class::TargetValidationError)
    end

    it "raises an error when no cpu cores are defined" do
      @node.hardware.cpu_total_cores = nil
      expect { @node.perf_collect_metrics('interval_name') }.to raise_error(
        described_class::TargetValidationError)
    end

    it "raises an error when memory is not defined" do
      @node.hardware.memory_mb = nil
      expect { @node.perf_collect_metrics('interval_name') }.to raise_error(
        described_class::TargetValidationError)
    end

    # TODO: include also sort_and_normalize in the tests
    METRICS_EXERCISES = [
      {
        :counters => [
          {
            :args => 'cpu/usage',
            :data => [
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 0},
              {'start' => 1446500020000, 'end' => 1446500040000, 'avg' => 4000000000}
            ]
          },
          {
            :args => 'network/tx',
            :data => [
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 0},
              {'start' => 1446500020000, 'end' => 1446500040000, 'avg' => 153600}
            ]
          },
          {
            :args => 'network/rx',
            :data => [
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 0},
              {'start' => 1446500020000, 'end' => 1446500040000, 'avg' => 51200}
            ]
          }
        ],
        :gauges => [
          {
            :args => 'memory/usage',
            :data => [
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 1073741824}
            ]
          }
        ],
        :node_expected      => {},
        :container_expected => {}
      },
      {
        :counters => [
          {
            :args => 'cpu/usage',
            :data => [
              {'start' => 1446499980000, 'end' => 1446500000000, 'avg' => 0},
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 4000000000}
            ]
          },
          {
            :args => 'network/tx',
            :data => [
              {'start' => 1446499980000, 'end' => 1446500000000, 'avg' => 0},
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 153600}
            ]
          },
          {
            :args => 'network/rx',
            :data => [
              {'start' => 1446499980000, 'end' => 1446500000000, 'avg' => 0},
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 51200}
            ]
          }
        ],
        :gauges => [
          {
            :args => 'memory/usage',
            :data => [
              {'start' => 1446500000000, 'end' => 1446500020000, 'avg' => 1073741824}
            ]
          }
        ],
        :node_expected      => {
          Time.at(1_446_500_000).utc => {
            "cpu_usage_rate_average"     => 10.0,
            "mem_usage_absolute_average" => 50.0,
            "net_usage_rate_average"     => 10.0
          }
        },
        :container_expected => {
          Time.at(1_446_500_000).utc => {
            "cpu_usage_rate_average"     => 10.0,
            "mem_usage_absolute_average" => 50.0
          }
        }
      }
    ]

    it "node counters and gauges are correctly processed" do
      METRICS_EXERCISES.each do |exercise|
        exercise[:counters].each do |metrics|
          allow_any_instance_of(described_class::CaptureContext)
            .to receive(:fetch_counters_data)
            .with("machine/node/#{metrics[:args]}")
            .and_return(metrics[:data])
        end

        exercise[:gauges].each do |metrics|
          allow_any_instance_of(described_class::CaptureContext)
            .to receive(:fetch_gauges_data)
            .with("machine/node/#{metrics[:args]}")
            .and_return(metrics[:data])
        end

        _, values_by_ts = @node.perf_collect_metrics('realtime')

        expect(values_by_ts['target']).to eq(exercise[:node_expected])
      end
    end

    it "container counters and gauges are correctly processed" do
      METRICS_EXERCISES.each do |exercise|
        exercise[:counters].each do |metrics|
          allow_any_instance_of(described_class::CaptureContext)
            .to receive(:fetch_counters_data)
            .with("container/group/#{metrics[:args]}")
            .and_return(metrics[:data])
        end

        exercise[:gauges].each do |metrics|
          allow_any_instance_of(described_class::CaptureContext)
            .to receive(:fetch_gauges_data)
            .with("container/group/#{metrics[:args]}")
            .and_return(metrics[:data])
        end

        _, values_by_ts = @container.perf_collect_metrics('realtime')

        expect(values_by_ts['target']).to eq(exercise[:container_expected])
      end
    end
  end
end
