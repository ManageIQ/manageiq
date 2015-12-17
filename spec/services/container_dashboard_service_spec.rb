require "spec_helper"
require 'recursive-open-struct'

describe ContainerDashboardService do
  context "providers" do
    it "filters containers providers with zero entity count and sorts providers by type correctly" do
      FactoryGirl.create(:ems_openshift, :hostname => "test2.com")
      FactoryGirl.create(:ems_openshift_enterprise, :hostname => "test3.com")
      FactoryGirl.create(:ems_atomic, :hostname => "test4.com")
      FactoryGirl.create(:ems_atomic_enterprise, :hostname => "test5.com")

      providers_data = ContainerDashboardService.new(nil, nil).providers

      # Kubernetes should not appear
      expect(providers_data).to eq([{
                                      :iconClass    => "pficon pficon-openshift",
                                      :count        => 2,
                                      :id           => :openshift,
                                      :providerType => :Openshift
                                    },
                                    {
                                      :iconClass    => "pficon pficon-atomic",
                                      :count        => 2,
                                      :id           => :atomic,
                                      :providerType => :Atomic
                                    }])
    end
  end

  context "node_utilization" do
    it "show aggregated metrics from last 30 days only" do
      MiqRegion.seed
      @zone = EvmSpecHelper.create_guid_miq_server_zone[2]
      @time_profile = FactoryGirl.create(:time_profile_utc)
      ems_openshift = FactoryGirl.create(:ems_openshift, :zone => @zone)
      ems_kubernetes = FactoryGirl.create(:ems_kubernetes, :zone => @zone)

      current_date = 7.days.ago
      old_date = 35.days.ago

      current_metric = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp                => current_date,
        :derived_memory_used      => 1024,
        :derived_vm_numvcpus      => 2,
        :derived_memory_available => 2048,
        :cpu_usage_rate_average   => 100,
        :time_profile             => @time_profile)

      old_metric = FactoryGirl.create(
        :metric_rollup_cm_daily,
        :timestamp                => old_date,
        :derived_memory_used      => 1024,
        :derived_vm_numvcpus      => 2,
        :derived_memory_available => 2048,
        :cpu_usage_rate_average   => 100,
        :time_profile             => @time_profile)

      ems_openshift.metric_rollups << current_metric
      ems_openshift.metric_rollups << old_metric
      ems_kubernetes.metric_rollups << current_metric.dup
      ems_kubernetes.metric_rollups << old_metric.dup

      controller = RecursiveOpenStruct.new(:current_user => {:get_timezone => "UTC"})
      node_utilization_all_providers = ContainerDashboardService.new(nil, controller).node_utilization
      node_utilization_single_provider = ContainerDashboardService.new(ems_openshift.id, controller).node_utilization

      expect(node_utilization_single_provider).to eq(
        :cpu => {
          :used  => 2,
          :total => 2,
          :xData => ["date", current_date.strftime("%Y-%m-%d")],
          :yData => ["used", 2]
        },
        :mem => {
          :used  => 1,
          :total => 2,
          :xData => ["date", current_date.strftime("%Y-%m-%d")],
          :yData => ["used", 1]
        }
      )

      expect(node_utilization_all_providers).to eq(
        :cpu => {
          :used  => 4,
          :total => 4,
          :xData => ["date", current_date.strftime("%Y-%m-%d")],
          :yData => ["used", 4]
        },
        :mem => {
          :used  => 2,
          :total => 4,
          :xData => ["date", current_date.strftime("%Y-%m-%d")],
          :yData => ["used", 2]
        }
      )
    end
  end
end
