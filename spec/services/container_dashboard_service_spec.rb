require 'recursive-open-struct'

describe ContainerDashboardService do
  let(:controller) { RecursiveOpenStruct.new(:current_user => {:get_timezone => "UTC"}) }
  let(:time_profile) { FactoryGirl.create(:time_profile_utc) }

  before(:each) do
    MiqRegion.seed
    @zone = EvmSpecHelper.create_guid_miq_server_zone[2]
  end

  context "providers" do
    it "filters containers providers with zero entity count and sorts providers by type correctly" do
      FactoryGirl.create(:ems_openshift, :hostname => "test2.com")
      FactoryGirl.create(:ems_openshift_enterprise, :hostname => "test3.com")
      FactoryGirl.create(:ems_atomic, :hostname => "test4.com")
      FactoryGirl.create(:ems_atomic_enterprise, :hostname => "test5.com")

      providers_data = ContainerDashboardService.new(nil, nil).providers

      # Kubernetes should not appear
      providers_data.each do |p|
        expect(p[:iconImage]).not_to be_nil
        expect(p[:count]).to eq(1)
      end
    end
  end

  context "node_utilization" do
    it "shows aggregated metrics from last 30 days only" do
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      ems_kubernetes = FactoryGirl.create(:ems_kubernetes, :zone => @zone)

      current_date = 7.days.ago
      old_date = 35.days.ago

      current_metric_openshift = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp                => current_date,
        :derived_memory_used      => 1024,
        :derived_vm_numvcpus      => 2,
        :derived_memory_available => 2048,
        :cpu_usage_rate_average   => 100,
        :time_profile             => time_profile)

      current_metric_kubernetes = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp                => current_date,
        :derived_memory_used      => 512,
        :derived_vm_numvcpus      => 1,
        :derived_memory_available => 1024,
        :cpu_usage_rate_average   => 100,
        :time_profile             => time_profile)

      old_metric = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp                => old_date,
        :derived_memory_used      => 1024,
        :derived_vm_numvcpus      => 2,
        :derived_memory_available => 2048,
        :cpu_usage_rate_average   => 100,
        :time_profile             => time_profile)

      ems_openshift.metric_rollups << current_metric_openshift
      ems_openshift.metric_rollups << old_metric
      ems_kubernetes.metric_rollups << current_metric_kubernetes
      ems_kubernetes.metric_rollups << old_metric.dup

      node_utilization_all_providers = described_class.new(nil, controller).ems_utilization
      node_utilization_single_provider = described_class.new(ems_openshift.id, controller).ems_utilization

      expect(node_utilization_single_provider).to eq(
        :cpu => {
          :used  => 2,
          :total => 2,
          :xData => [current_date.strftime("%Y-%m-%d")],
          :yData => [2]
        },
        :mem => {
          :used  => 1,
          :total => 2,
          :xData => [current_date.strftime("%Y-%m-%d")],
          :yData => [1]
        }
      )

      expect(node_utilization_all_providers).to eq(
        :cpu => {
          :used  => 3,
          :total => 3,
          :xData => [current_date.strftime("%Y-%m-%d")],
          :yData => [3]
        },
        :mem => {
          :used  => 2,
          :total => 3,
          :xData => [current_date.strftime("%Y-%m-%d")],
          :yData => [2]
        }
      )
    end

    it "returns hash with nil values when no metrics available" do
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      node_utilization_all_providers = described_class.new(nil, controller).ems_utilization
      node_utilization_single_provider = described_class.new(ems_openshift.id, controller).ems_utilization
      expect(node_utilization_all_providers).to eq(:cpu => nil, :mem => nil)
      expect(node_utilization_single_provider).to eq(:cpu => nil, :mem => nil)
    end
  end

  context "heatmaps" do
    it "returns hash with nil values when no metrics available" do
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      heatmaps_all_providers = described_class.new(nil, controller).heatmaps
      heatmaps_single_provider = described_class.new(ems_openshift.id, controller).heatmaps
      expect(heatmaps_all_providers).to eq(:nodeCpuUsage => nil, :nodeMemoryUsage => nil)
      expect(heatmaps_single_provider).to eq(:nodeCpuUsage => nil, :nodeMemoryUsage => nil)
    end
  end

  context "network trends" do
    it "shows daily network trends from last 30 days only" do
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      ems_kubernetes = FactoryGirl.create(:ems_kubernetes, :zone => @zone)

      current_date = 7.days.ago
      old_date = 35.days.ago

      current_metric_openshift = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp              => current_date,
        :net_usage_rate_average => 1000,
        :time_profile           => time_profile)

      current_metric_kubernetes = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp              => current_date,
        :net_usage_rate_average => 1500,
        :time_profile           => time_profile)

      old_metric = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp              => old_date,
        :net_usage_rate_average => 1500,
        :time_profile           => time_profile)

      ems_openshift.metric_rollups << current_metric_openshift
      ems_openshift.metric_rollups << old_metric
      ems_kubernetes.metric_rollups << current_metric_kubernetes
      ems_kubernetes.metric_rollups << old_metric.dup

      daily_network_trends = described_class.new(nil, controller).daily_network_metrics
      daily_network_trends_single_provider = described_class.new(ems_openshift.id, controller).daily_network_metrics

      expect(daily_network_trends_single_provider).to eq(
        :xData => [current_date.strftime("%Y-%m-%d")],
        :yData => [1000]
      )

      expect(daily_network_trends).to eq(
        :xData => [current_date.strftime("%Y-%m-%d")],
        :yData => [2500]
      )
    end

    it "show daily hourly network trends from last 24 hours only" do
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      ems_kubernetes = FactoryGirl.create(:ems_kubernetes, :zone => @zone)

      current_date = 2.hours.ago
      old_date = 2.days.ago

      current_metric_openshift = FactoryGirl.create(
        :metric_rollup_cm_hr,
        :timestamp              => current_date,
        :net_usage_rate_average => 1000,
        :time_profile           => time_profile)

      current_metric_kubernetes = FactoryGirl.create(
        :metric_rollup_cm_hr,
        :timestamp              => current_date,
        :net_usage_rate_average => 1500,
        :time_profile           => time_profile)

      old_metric = FactoryGirl.create(
        :metric_rollup_cm_hr,
        :timestamp              => old_date,
        :net_usage_rate_average => 1500,
        :time_profile           => time_profile)

      ems_openshift.metric_rollups << current_metric_openshift
      ems_openshift.metric_rollups << old_metric
      ems_kubernetes.metric_rollups << current_metric_kubernetes
      ems_kubernetes.metric_rollups << old_metric.dup

      hourly_network_trends = described_class.new(nil, controller).hourly_network_metrics
      hourly_network_trends_single_provider = described_class.new(ems_openshift.id, controller).hourly_network_metrics

      expect(hourly_network_trends_single_provider).to eq(
        :xData => [current_date.beginning_of_hour.utc],
        :yData => [1000]
      )

      expect(hourly_network_trends).to eq(
        :xData => [current_date.beginning_of_hour.utc],
        :yData => [2500]
      )
    end

    it "returns hash with nil values when no metrics available" do
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      hourly_network_trends = described_class.new(nil, controller).hourly_network_metrics
      hourly_network_trends_single_provider = described_class.new(ems_openshift.id, controller).hourly_network_metrics

      daily_network_trends = described_class.new(nil, controller).daily_network_metrics
      daily_network_trends_single_provider = described_class.new(ems_openshift.id, controller).daily_network_metrics

      expect(hourly_network_trends).to eq(nil)
      expect(hourly_network_trends_single_provider).to eq(nil)
      expect(daily_network_trends).to eq(nil)
      expect(daily_network_trends_single_provider).to eq(nil)
    end
  end
end
