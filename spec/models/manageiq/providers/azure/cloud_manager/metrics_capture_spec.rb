require 'azure-armrest'

describe ManageIQ::Providers::Azure::CloudManager::MetricsCapture do
  let(:ems)      { FactoryGirl.create(:ems_azure) }
  let(:vm)       { FactoryGirl.build(:vm_azure, :ext_management_system => ems, :ems_ref => "my_ems_ref") }
  let(:counters) { stage_counter_data }

  context "#perf_collect_metrics" do
    it "raises an error when no EMS is defined" do
      vm = FactoryGirl.build(:vm_azure, :ext_management_system => nil)
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /No EMS defined/)
    end

    it "parses and handles cpu metrics" do
      metric_data = [
        build_metric_data(0.788455, "2016-07-23T07:20:00.5580968Z"),
        build_metric_data(0.888455, "2016-07-23T07:21:00.5580968Z"),
        build_metric_data(0.988455, "2016-07-23T07:22:00.5580968Z")
      ]
      stage_metrics(metric_data, [Azure::Armrest::Insights::Metric.new(counters)])

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
  end

  def stage_metrics(metric_data, counters)
    armrest_service = double("::Azure::Armrest::ArmrestService")
    allow(ems).to receive(:connect).and_return(armrest_service)

    metrics_service = double("Azure::Armrest::Insights::MetricsService")
    storage_acc_service = double(
      "Azure::Armrest::StorageAccountService",
      :name           => "defaultstorage",
      :resource_group => "Default-Storage")

    allow_any_instance_of(described_class).to receive(:with_metrics_services).and_yield(metrics_service, storage_acc_service)
    allow_any_instance_of(described_class).to receive(:storage_accounts) { [storage_acc_service] }
    allow_any_instance_of(described_class).to receive(:get_counters) { counters }
    allow(storage_acc_service).to receive(:list_account_keys) { { "key1"=>"key1" } }
    allow(storage_acc_service).to receive(:table_data) { metric_data }
  end

  def stage_counter_data
    {
      "name"                 => {
        "value" => "\\Processor(_Total)\\% Processor Time",
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
