require 'fog/google'

describe ManageIQ::Providers::Google::CloudManager::MetricsCapture do
  let(:ems) { FactoryGirl.create(:ems_google) }
  let(:vm) { FactoryGirl.build(:vm_google, :ext_management_system => ems, :ems_ref => "my_ems_ref") }

  context "#perf_collect_metrics" do
    it "raises an error when no EMS is defined" do
      vm = FactoryGirl.build(:vm_google, :ext_management_system => nil)
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /No EMS defined/)
    end

    it "returns [{},{}] when target is not a vm" do
      template = FactoryGirl.build(:template_google, :ext_management_system => ems)
      expect(template.perf_collect_metrics('interval_name')).to eq([{}, {}])
    end

    it "has definitions for cpu, network and disk metrics" do
      # Don't stage any metrics
      stage_metrics({})

      counters_by_id, = vm.perf_collect_metrics('interval_name')

      expect(counters_by_id).to have_key("my_ems_ref")
      expect(counters_by_id["my_ems_ref"]).to have_key("cpu_usage_rate_average")
      expect(counters_by_id["my_ems_ref"]).to have_key("disk_usage_rate_average")
      expect(counters_by_id["my_ems_ref"]).to have_key("net_usage_rate_average")
    end

    it "parses and handles cpu metrics" do
      # Stage a single cpu metric
      stage_metrics(
        "compute.googleapis.com/instance/cpu/utilization" => [
          {
            "points" => [
              {
                "start"       => "2016-06-23T00:00:00.000Z",
                "doubleValue" => "0.42"
              }
            ]
          }
        ]
      )

      _, counter_values_by_id_and_ts = vm.perf_collect_metrics('interval_name')

      expect(counter_values_by_id_and_ts).to eq(
        "my_ems_ref" => {
          Time.zone.parse("2016-06-23T00:00:00.000Z") => {
            "cpu_usage_rate_average" => 42.0
          },
          Time.zone.parse("2016-06-23T00:00:20.000Z") => {
            "cpu_usage_rate_average" => 42.0
          },
          Time.zone.parse("2016-06-23T00:00:40.000Z") => {
            "cpu_usage_rate_average" => 42.0
          }
        }
      )
    end

    it "parses and aggregates multiple disks" do
      stage_metrics(
        "compute.googleapis.com/instance/disk/read_bytes_count" => [
          { # Disk 1
            "points" => [
              {
                "start"      => "2016-06-23T00:00:00.000Z",
                "int64Value" => "7864020"
              }
            ]
          },
          { # Disk 2
            "points" => [
              {
                "start"      => "2016-06-23T00:00:00.000Z",
                "int64Value" => "300"
              }
            ]
          }
        ]
      )

      _, counter_values_by_id_and_ts = vm.perf_collect_metrics('interval_name')

      expect(counter_values_by_id_and_ts).to eq(
        "my_ems_ref" => {
          Time.zone.parse("2016-06-23T00:00:00.000Z") => {
            "disk_usage_rate_average" => 128.0 # 7864320 bytes/min = 128 kb/s
          },
          Time.zone.parse("2016-06-23T00:00:20.000Z") => {
            "disk_usage_rate_average" => 128.0
          },
          Time.zone.parse("2016-06-23T00:00:40.000Z") => {
            "disk_usage_rate_average" => 128.0
          }
        }
      )
    end

    it "parses and aggregates read and write on disk" do
      stage_metrics(
        "compute.googleapis.com/instance/disk/read_bytes_count"  => [
          {
            "points" => [
              {
                "start"      => "2016-06-23T00:00:00.000Z",
                "int64Value" => "982252"
              }
            ]
          },
        ],
        "compute.googleapis.com/instance/disk/write_bytes_count" => [
          {
            "points" => [
              {
                "start"      => "2016-06-23T00:00:00.000Z",
                "int64Value" => "788"
              }
            ]
          },
        ]
      )

      _, counter_values_by_id_and_ts = vm.perf_collect_metrics('interval_name')

      expect(counter_values_by_id_and_ts).to eq(
        "my_ems_ref" => {
          Time.zone.parse("2016-06-23T00:00:00.000Z") => {
            "disk_usage_rate_average" => 16.0 # 983040 bytes/min = 16 kb/s
          },
          Time.zone.parse("2016-06-23T00:00:20.000Z") => {
            "disk_usage_rate_average" => 16.0
          },
          Time.zone.parse("2016-06-23T00:00:40.000Z") => {
            "disk_usage_rate_average" => 16.0
          }
        }
      )
    end

    it "parses and aggregates read and write on network" do
      stage_metrics(
        "compute.googleapis.com/instance/network/received_bytes_count" => [
          {
            "points" => [
              {
                "start"      => "2016-06-23T00:00:00.000Z",
                "int64Value" => "982252"
              }
            ]
          },
        ],
        "compute.googleapis.com/instance/network/sent_bytes_count"     => [
          {
            "points" => [
              {
                "start"      => "2016-06-23T00:00:00.000Z",
                "int64Value" => "788"
              }
            ]
          },
        ]
      )

      _, counter_values_by_id_and_ts = vm.perf_collect_metrics('interval_name')

      expect(counter_values_by_id_and_ts).to eq(
        "my_ems_ref" => {
          Time.zone.parse("2016-06-23T00:00:00.000Z") => {
            "net_usage_rate_average" => 16.0  # 983040 bytes/min = 16 kb/s
          },
          Time.zone.parse("2016-06-23T00:00:20.000Z") => {
            "net_usage_rate_average" => 16.0
          },
          Time.zone.parse("2016-06-23T00:00:40.000Z") => {
            "net_usage_rate_average" => 16.0
          }
        }
      )
    end
  end

  def stage_metrics(metrics)
    timeseries_collection = double("timeseries_collection")
    # By default, missing metrics return empty lists
    allow(timeseries_collection).to receive(:all) { [] }

    # Annoyingly fog returns an object for each time series rather than a hash
    # so we're forced to use test doubles here
    metrics.each do |metric_name, tss|
      time_series_list = []
      tss.each do |ts|
        time_series = double(:points => ts["points"])
        time_series_list << time_series
      end
      allow(timeseries_collection).to receive(:all).with(metric_name, anything, anything) { time_series_list }
    end

    # Create a monitoring double and ensure it gets used instead of the real client
    monitoring = double("::Fog::Google::Monitoring")
    allow(monitoring).to receive(:timeseries_collection) { timeseries_collection }
    allow(::Fog::Google::Monitoring).to receive(:new) { monitoring }
  end
end
