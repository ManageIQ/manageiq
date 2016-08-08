require 'azure-armrest'

describe ManageIQ::Providers::Azure::CloudManager::MetricsCapture do
  let(:ems)      { FactoryGirl.create(:ems_azure) }
  let(:vm)       { FactoryGirl.build(:vm_azure, :ext_management_system => ems, :ems_ref => "my_ems_ref") }

  context "#perf_collect_metrics" do
    it "raises an error when no EMS is defined" do
      vm = FactoryGirl.build(:vm_azure, :ext_management_system => nil)
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /No EMS defined/)
    end

    it "has definitions for cpu, network and disk metrics" do
      # Don't stage any metrics
      counters    = []
      metric_data = []
      stage_metrics(metric_data, counters)

      counters_by_id, = vm.perf_collect_metrics('interval_name')

      expect(counters_by_id).to have_key("my_ems_ref")
      expect(counters_by_id["my_ems_ref"]).to have_key("cpu_usage_rate_average")
      expect(counters_by_id["my_ems_ref"]).to have_key("disk_usage_rate_average")
      expect(counters_by_id["my_ems_ref"]).to have_key("net_usage_rate_average")
    end

    it "parses and handles cpu metrics" do
      counters = stage_counter_data(["\\Processor(_Total)\\% Processor Time"])

      metric_data = [
        build_metric_data(0.788455, "2016-07-23T07:20:00.5580968Z"),
        build_metric_data(0.888455, "2016-07-23T07:21:00.5580968Z"),
        build_metric_data(0.988455, "2016-07-23T07:22:00.5580968Z")
      ]
      stage_metrics(metric_data, counters)

      _, metrics_by_id_and_ts = vm.perf_collect_metrics('interval_name')

      expect(metrics_by_id_and_ts).to eq(
        "my_ems_ref" => {
          "2016-07-23T07:20:20Z" => {
            "cpu_usage_rate_average" => 0.888455
          },
          "2016-07-23T07:20:40Z" => {
            "cpu_usage_rate_average" => 0.888455
          },
          "2016-07-23T07:21:00Z" => {
            "cpu_usage_rate_average" => 0.888455
          },
          "2016-07-23T07:21:20Z" => {
            "cpu_usage_rate_average" => 0.988455
          },
          "2016-07-23T07:21:40Z" => {
            "cpu_usage_rate_average" => 0.988455
          },
          "2016-07-23T07:22:00Z" => {
            "cpu_usage_rate_average" => 0.988455
          },
        }
      )
    end

    it "parses and aggregates read and write on disk" do
      counters = stage_counter_data(["\\PhysicalDisk(_Total)\\Disk Read Bytes/sec",
                                     "\\PhysicalDisk(_Total)\\Disk Write Bytes/sec"])

      metric_data = [
        build_metric_data(982_252_000, "2016-07-23T07:20:00.5580968Z"),
        build_metric_data(982_252_000, "2016-07-23T07:21:00.5580968Z"),
        build_metric_data(982_252_000, "2016-07-23T07:22:00.5580968Z")
      ]
      stage_metrics(metric_data, counters)

      _, metrics_by_id_and_ts = vm.perf_collect_metrics('interval_name')

      expect(metrics_by_id_and_ts).to eq(
        "my_ems_ref" => {
          "2016-07-23T07:20:20Z" => {
            "disk_usage_rate_average" => 1_918_460
          },
          "2016-07-23T07:20:40Z" => {
            "disk_usage_rate_average" => 1_918_460
          },
          "2016-07-23T07:21:00Z" => {
            "disk_usage_rate_average" => 1_918_460
          },
          "2016-07-23T07:21:20Z" => {
            "disk_usage_rate_average" => 1_918_460
          },
          "2016-07-23T07:21:40Z" => {
            "disk_usage_rate_average" => 1_918_460
          },
          "2016-07-23T07:22:00Z" => {
            "disk_usage_rate_average" => 1_918_460
          }
        }
      )
    end
  end

  def stage_metrics(metric_data = nil, counters = nil)
    armrest_service = double("::Azure::Armrest::ArmrestService")
    allow(ems).to receive(:connect).and_return(armrest_service)

    metrics_service     = double("Azure::Armrest::Insights::MetricsService")
    storage_acc_service = double(
      "Azure::Armrest::StorageAccountService",
      :name           => "defaultstorage",
      :resource_group => "Default-Storage")

    allow_any_instance_of(described_class).to receive(:with_metrics_services)
      .and_yield(metrics_service, storage_acc_service)
    allow_any_instance_of(described_class).to receive(:storage_accounts) { [storage_acc_service] }
    allow_any_instance_of(described_class).to receive(:get_counters) { counters }
    allow(storage_acc_service).to receive(:list_account_keys) { { "key1"=>"key1" } }
    allow(storage_acc_service).to receive(:table_data) { metric_data }
  end

  def stage_counter_data(counters)
    metric_availabilities = []

    counters.each do |counter|
      azure_metric = Azure::Armrest::Insights::Metric.new(metric_hash(counter))
      metric_availabilities << azure_metric
    end
    metric_availabilities
  end

  def metric_hash(counter)
    {
      "name"                 => {
        "value" => counter,
      },
      "metricAvailabilities" => [
        {
          "timeGrain" => "PT1M",
          "location"  => {
            "tableEndpoint" => "https://defaultstorage.table.core.windows.net/",
            "tableInfo"     => [{ "tableName" => "table_name" }],
            "partitionKey"  => "key"
          }
        }
      ]
    }
  end

  def build_metric_data(consumption_value, timestamp)
    Azure::Armrest::StorageAccount::TableData.new(
      "average"    => consumption_value,
      "_timestamp" => timestamp
    )
  end
end
