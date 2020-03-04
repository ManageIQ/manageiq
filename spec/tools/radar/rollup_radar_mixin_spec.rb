require './tools/radar/rollup_radar_mixin.rb'

describe RollupRadarMixin do
  include RollupRadarMixin

  let(:ems) { FactoryBot.create(:ems_openshift, :name => 'OpenShiftProvider') }

  let(:container_project) do
    FactoryBot.create(:container_project, :ext_management_system => ems)
  end

  let(:container_group) do
    FactoryBot.create(:container_group, :container_project     => container_project,
                                         :ext_management_system => ems)
  end

  let(:container_image_a) do
    FactoryBot.create(:container_image,
                       :ext_management_system => ems,
                       :custom_attributes     => [custom_attribute_a])
  end

  let(:container_a) do
    FactoryBot.create(:container,
                       :name                  => "A",
                       :container_group       => container_group,
                       :container_image       => container_image_a,
                       :ext_management_system => ems)
  end

  let(:custom_attribute_a) do
    FactoryBot.create(:custom_attribute,
                       :name    => 'com.redhat.component',
                       :value   => 'EAP7',
                       :section => 'docker_labels')
  end

  let(:container_b) do
    FactoryBot.create(:container,
                       :name                  => "B",
                       :container_group       => container_group,
                       :container_image       => container_image_b,
                       :ext_management_system => ems)
  end

  let(:container_image_b) do
    FactoryBot.create(:container_image,
                       :ext_management_system => ems,
                       :custom_attributes     => [custom_attribute_b])
  end

  let(:custom_attribute_b) do
    FactoryBot.create(:custom_attribute,
                       :name    => 'com.redhat.component',
                       :value   => 'EAP7',
                       :section => 'docker_labels')
  end

  let(:ts)              { Time.parse('2012-09-01 23:59:59Z').utc.in_time_zone(Metric::Helper.get_time_zone(nil)) }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end)       { ts.end_of_month.utc }
  let(:report_run_time) { month_end }

  def add_metric_for(resources, timestamp)
    Array(resources).each do |resource|
      metric_rollup_params = metric_params(timestamp, resource)
      metric_rollup_params[:timestamp]     = timestamp
      metric_rollup_params[:resource_id]   = resource.id
      metric_rollup_params[:resource_name] = resource.name
      params = [:metric, metric_rollup_params].compact
      resource.metrics << FactoryBot.create(*params)
    end
  end

  def basic_metric_params(cpu_usage, num_cores)
    {:parent_ems_id          => ems.id,
     :tag_names              => "",
     :cpu_usage_rate_average => cpu_usage,
     :derived_vm_numvcpus    => num_cores}
  end

  let(:default_metric_values) { basic_metric_params(100, 1) }

  def metric_params(timestamp, resource)
    metrics_settings[resource][timestamp] || default_metric_values
  end

  def add_metrics(containers)
    rollup_step = 20.seconds
    start_time  = month_beginning

    (start_time...(start_time + 2.hours)).step_value(1.hour).each do |sample_time|
      containers.each do |container|
        start_sample_time = sample_time
        add_metric_for(container, start_sample_time)
        start_sample_time += rollup_step
        add_metric_for(container, start_sample_time)
        start_sample_time += rollup_step
        add_metric_for(container, start_sample_time)
      end
    end
  end

  def check_results(results, expected)
    results.sort_by! { |x| Time.parse(x['hourly_timestamp']).utc }
    expected.sort_by! { |x| Time.parse(x['hourly_timestamp']).utc }

    results.zip(expected).each do |result, expected_result|
      expect(result).to(include(expected_result))
    end
  end

  context 'with 2 containers and 100% usage(both 1 core)' do
    let(:metrics_settings) do
      t = month_beginning

      sett = {}
      sett[container_a] = {}
      sett[container_b] = {}

      # matrix of metrics
      sett[container_a][t] = basic_metric_params(100, 1) # 1 core
      sett
    end

    before do
      add_metrics([container_a, container_b])
    end

    it 'calculates rollups' do
      results = get_hourly_maxes_per_group("com.redhat.component", month_beginning...month_end)

      exp = [{"label_name"             => "com.redhat.component",
              "label_value"            => "EAP7",
              "container_project_name" => container_project.name,
              "hourly_timestamp"       => "2012-09-01 00:00:00",
              "max_sum_used_cores"     => 2.0},
             {"label_name"             => "com.redhat.component",
              "label_value"            => "EAP7",
              "container_project_name" => container_project.name,
              "hourly_timestamp"       => "2012-09-01 01:00:00",
              "max_sum_used_cores"     => 2.0}]

      check_results(results, exp)
    end
  end

  context 'with 50 % usage of both cores' do
    let(:metrics_settings) do
      t = month_beginning

      sett = {}
      sett[container_a] = {}
      sett[container_b] = {}

      # matrix of metrics
      sett[container_a][t] = basic_metric_params(50, 1)
      sett[container_b][t] = basic_metric_params(50, 1)

      sett[container_a][t + 20.seconds] = basic_metric_params(50, 1)
      sett[container_b][t + 20.seconds] = basic_metric_params(50, 1)

      sett[container_a][t + 40.seconds] = basic_metric_params(50, 1)
      sett[container_b][t + 40.seconds] = basic_metric_params(50, 1)

      t += 1.hour
      # matrix of metrics
      sett[container_a][t] = basic_metric_params(50, 1)
      sett[container_b][t] = basic_metric_params(50, 1)

      sett[container_a][t + 20.seconds] = basic_metric_params(50, 1)
      sett[container_b][t + 20.seconds] = basic_metric_params(50, 1)

      sett[container_a][t + 40.seconds] = basic_metric_params(50, 1)
      sett[container_b][t + 40.seconds] = basic_metric_params(50, 1)

      sett
    end

    before do
      add_metrics([container_a, container_b])
    end

    it 'calculates rollups' do
      results = get_hourly_maxes_per_group("com.redhat.component", month_beginning...month_end)

      exp = [{"label_name"             => "com.redhat.component",
              "label_value"            => "EAP7",
              "container_project_name" => container_project.name,
              "hourly_timestamp"       => "2012-09-01 00:00:00",
              "max_sum_used_cores"     => 1.0},
             {"label_name"             => "com.redhat.component",
              "label_value"            => "EAP7",
              "container_project_name" => container_project.name,
              "hourly_timestamp"       => "2012-09-01 01:00:00",
              "max_sum_used_cores"     => 1.0}]

      check_results(results, exp)
    end

    context 'container A has 100% usage metric at t + 20.second' do
      let(:metrics_settings) do
        t = month_beginning

        sett = {}
        sett[container_a] = {}
        sett[container_b] = {}

        # matrix of metrics
        sett[container_a][t] = basic_metric_params(50, 1)
        sett[container_b][t] = basic_metric_params(50, 1)

        sett[container_a][t + 20.seconds] = basic_metric_params(100, 1) # 100 % usage
        sett[container_b][t + 20.seconds] = basic_metric_params(50, 1)

        sett[container_a][t + 40.seconds] = basic_metric_params(50, 1)
        sett[container_b][t + 40.seconds] = basic_metric_params(50, 1)

        t += 1.hour
        # matrix of metrics
        sett[container_a][t] = basic_metric_params(50, 1)
        sett[container_b][t] = basic_metric_params(50, 1)

        sett[container_a][t + 20.seconds] = basic_metric_params(50, 1)
        sett[container_b][t + 20.seconds] = basic_metric_params(50, 1)

        sett[container_a][t + 40.seconds] = basic_metric_params(50, 1)
        sett[container_b][t + 40.seconds] = basic_metric_params(50, 1)

        sett
      end

      it 'calculates rollups' do
        results = get_hourly_maxes_per_group("com.redhat.component", month_beginning...month_end)

        exp = [{"label_name"             => "com.redhat.component",
                "label_value"            => "EAP7",
                "container_project_name" => container_project.name,
                "hourly_timestamp"       => "2012-09-01 00:00:00",
                "max_sum_used_cores"     => 1.5},
               {"label_name"             => "com.redhat.component",
                "label_value"            => "EAP7",
                "container_project_name" => container_project.name,
                "hourly_timestamp"       => "2012-09-01 01:00:00",
                "max_sum_used_cores"     => 1.0}]

        check_results(results, exp)
      end

      it 'returns empty result with non-existing label' do
        results = get_hourly_maxes_per_group("XXXXXX", month_beginning...month_end)
        check_results(results, [])
      end
    end
  end

  context 'with different label for first container' do
    let(:metrics_settings) do
      t = month_beginning

      sett = {}
      sett[container_a] = {}
      sett[container_b] = {}

      # matrix of metrics
      sett[container_a][t] = basic_metric_params(20, 1)
      sett[container_a][t + 20.seconds] = basic_metric_params(20, 1)
      sett[container_a][t + 40.seconds] = basic_metric_params(20, 1)
      sett
    end

    let(:custom_attribute_a) do
      FactoryBot.create(:custom_attribute,
                         :name    => 'com.redhat.component_different',
                         :value   => 'EAP7',
                         :section => 'docker_labels')
    end

    before do
      add_metrics([container_a, container_b])
    end

    it 'calculates rollups' do
      results = get_hourly_maxes_per_group("com.redhat.component_different", month_beginning...month_end)

      exp = [{"label_name"             => "com.redhat.component_different",
              "label_value"            => "EAP7",
              "container_project_name" => container_project.name,
              "hourly_timestamp"       => "2012-09-01 00:00:00",
              "max_sum_used_cores"     => 0.2},
             {"label_name"             => "com.redhat.component_different",
              "label_value"            => "EAP7",
              "container_project_name" => container_project.name,
              "hourly_timestamp"       => "2012-09-01 01:00:00",
              "max_sum_used_cores"     => 1.0}]

      check_results(results, exp)
    end
  end

  after do
    Timecop.return
  end
end
