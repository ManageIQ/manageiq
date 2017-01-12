require Rails.root.join('spec/tools/vim_data/vim_data_test_helper')

describe ManageIQ::Providers::Vmware::InfraManager::MetricsCapture do
  before(:each) do
    MiqRegion.seed

    guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  context "as vmware" do
    before :each do
      @ems_vmware = FactoryGirl.create(:ems_vmware, :zone => @zone)
    end

    context "with a vm" do
      before(:each) do
        @vm = FactoryGirl.create(:vm_perf, :ext_management_system => @ems_vmware)
      end

      context "and a fake vim handle" do
        before(:each) do
          allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:connect).and_return(FakeMiqVimHandle.new)
          allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:disconnect).and_return(true)
        end

        context "collecting vm realtime data" do
          before(:each) do
            @counters_by_mor, @counter_values_by_mor_and_ts = @vm.perf_collect_metrics('realtime')
          end

          it "should have collected counters and values" do
            expect(@counters_by_mor.length).to eq(1)
            expect(@counter_values_by_mor_and_ts.length).to eq(1)

            counters = @counters_by_mor[@vm.ems_ref_obj]
            expect(counters.length).to eq(18)

            expected = [
              ["realtime", "cpu_ready_delta_summation",           ""],
              ["realtime", "cpu_ready_delta_summation",           "0"],
              ["realtime", "cpu_system_delta_summation",          "0"],
              ["realtime", "cpu_usage_rate_average",              ""],
              ["realtime", "cpu_usagemhz_rate_average",           ""],
              ["realtime", "cpu_usagemhz_rate_average",           "0"],
              ["realtime", "cpu_used_delta_summation",            "0"],
              ["realtime", "cpu_wait_delta_summation",            "0"],
              ["realtime", "disk_usage_rate_average",             ""],
              ["realtime", "mem_swapin_absolute_average",         ""],
              ["realtime", "mem_swapout_absolute_average",        ""],
              ["realtime", "mem_swapped_absolute_average",        ""],
              ["realtime", "mem_swaptarget_absolute_average",     ""],
              ["realtime", "mem_usage_absolute_average",          ""],
              ["realtime", "mem_vmmemctl_absolute_average",       ""],
              ["realtime", "mem_vmmemctltarget_absolute_average", ""],
              ["realtime", "net_usage_rate_average",              ""],
              ["realtime", "sys_uptime_absolute_latest",          ""],
            ]

            selected = counters.values.collect { |c| c.values_at(:capture_interval_name, :counter_key, :instance) }
            expect(selected).to match_array(expected)

            counter_values = @counter_values_by_mor_and_ts[@vm.ems_ref_obj]
            timestamps = counter_values.keys.sort
            expect(timestamps.first).to eq("2011-08-12T20:33:20Z")
            expect(timestamps.last).to eq("2011-08-12T21:33:00Z")

            # Check every timestamp is present
            expect(counter_values.length).to eq(180)

            ts = timestamps.first
            until ts > timestamps.last
              expect(counter_values.key?(ts)).to be_truthy
              ts = (Time.parse(ts).utc + 20.seconds).iso8601
            end

            # Check a few specific values

            # Since the key for each counter value is a vim counter id, we have to
            #   remove that from the comparison.  The format is:
            #   [[ts, sorted_values], [ts, sorted_values], ...]
            expected = [
              ["2011-08-12T20:33:20Z", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 7, 8, 8, 8, 16, 16, 30, 39, 40, 40, 41, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 120, 138, 160, 200, 200, 265, 399, 6000, 11612, 19048, 20968, 39496, 49400, 184728, 474416, 523816]],
              ["2011-08-12T21:03:00Z", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 6, 8, 8, 8, 16, 16, 51, 54, 100, 100, 160, 164, 169, 169, 181, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 342, 599, 6000, 11216, 18928, 31456, 39976, 47240, 186508, 476576, 523816]],
              ["2011-08-12T21:33:00Z", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 7, 10, 10, 10, 15, 15, 40, 40, 42, 45, 100, 100, 100, 100, 100, 100, 109, 150, 160, 200, 200, 200, 200, 200, 200, 286, 599, 6000, 11148, 19028, 31456, 39888, 48968, 188307, 474848, 523816]]
            ]
            selected = expected.transpose[0].collect { |k| [k, counter_values[k].values.sort] }

            expect(selected).to match_array(expected)
          end
        end

        context "capturing vm realtime data" do
          before(:each) do
            @vm.perf_capture_realtime
          end

          it "should have collected performances" do
            # Check Vm record was updated
            expect(@vm.last_perf_capture_on.utc.iso8601).to eq("2011-08-12T21:33:00Z")

            # Check performances
            expect(Metric.count).to eq(180)

            # Check every timestamp is present; performance realtime timestamps
            #   are to the nearest 20 second interval
            ts = "2011-08-12T20:33:20Z"
            Metric.order(:timestamp).each do |p|
              p_ts = p.timestamp.utc
              expect(p_ts.iso8601).to eq(ts)
              ts = (p_ts + 20.seconds).iso8601
            end

            # Check a few specific values
            expected = [
              {"timestamp" => Time.parse("2011-08-12T20:33:20Z").utc, "capture_interval" => 20, "resource_type" => "VmOrTemplate", "mem_swapin_absolute_average" => 0.0, "derived_storage_vm_count_unmanaged" => nil, "derived_storage_vm_count_registered" => nil, "derived_storage_mem_unregistered" => nil, "sys_uptime_absolute_latest" => 184728.0, "disk_usage_rate_average" => 8.0, "derived_vm_used_disk_storage" => nil, "derived_vm_count_on" => 0, "derived_storage_used_registered" => nil, "derived_storage_snapshot_managed" => nil, "derived_storage_disk_unmanaged" => nil, "derived_host_count_off" => 0, "cpu_usagemhz_rate_average" => 41.0, "derived_storage_vm_count_managed" => nil, "intervals_in_rollup" => nil, "derived_vm_count_off" => 0, "derived_vm_allocated_disk_storage" => nil, "derived_storage_disk_unregistered" => nil, "derived_storage_disk_managed" => nil, "derived_cpu_reserved" => nil, "cpu_wait_delta_summation" => 19048.0, "cpu_used_delta_summation" => 265.0, "capture_interval_name" => "realtime", "mem_vmmemctl_absolute_average" => 0.0, "mem_swapped_absolute_average" => 0.0, "derived_memory_available" => nil, "min_max" => nil, "disk_devicelatency_absolute_average" => nil, "derived_storage_used_unregistered" => nil, "derived_storage_used_unmanaged" => nil, "derived_storage_used_managed" => nil, "derived_storage_snapshot_unregistered" => nil, "derived_storage_snapshot_registered" => nil, "derived_memory_used" => nil, "mem_swaptarget_absolute_average" => 0.0, "derived_storage_vm_count_unregistered" => nil, "derived_storage_mem_managed" => nil, "derived_host_count_on" => 0, "tag_names" => "", "mem_swapout_absolute_average" => 0.0, "disk_queuelatency_absolute_average" => nil, "derived_storage_mem_registered" => nil, "assoc_ids" => {:storages => {:off => [], :on => []}}, "resource_name" => "MIQ-WEBSVR1", "net_usage_rate_average" => 0.0, "mem_vmmemctltarget_absolute_average" => 0.0, "disk_kernellatency_absolute_average" => nil, "derived_storage_snapshot_unmanaged" => nil, "derived_memory_reserved" => nil, "mem_usage_absolute_average" => 3.99, "derived_storage_mem_unmanaged" => nil, "derived_storage_free" => nil, "derived_cpu_available" => nil, "cpu_ready_delta_summation" => 40.0, "derived_storage_total" => nil, "derived_storage_disk_registered" => nil, "cpu_usage_rate_average" => 1.38, "cpu_system_delta_summation" => 2.0},
              {"timestamp" => Time.parse("2011-08-12T21:03:00Z").utc, "capture_interval" => 20, "resource_type" => "VmOrTemplate", "mem_swapin_absolute_average" => 0.0, "derived_storage_vm_count_unmanaged" => nil, "derived_storage_vm_count_registered" => nil, "derived_storage_mem_unregistered" => nil, "sys_uptime_absolute_latest" => 186508.0, "disk_usage_rate_average" => 8.0, "derived_vm_used_disk_storage" => nil, "derived_vm_count_on" => 0, "derived_storage_used_registered" => nil, "derived_storage_snapshot_managed" => nil, "derived_storage_disk_unmanaged" => nil, "derived_host_count_off" => 0, "cpu_usagemhz_rate_average" => 54.0, "derived_storage_vm_count_managed" => nil, "intervals_in_rollup" => nil, "derived_vm_count_off" => 0, "derived_vm_allocated_disk_storage" => nil, "derived_storage_disk_unregistered" => nil, "derived_storage_disk_managed" => nil, "derived_cpu_reserved" => nil, "cpu_wait_delta_summation" => 18928.0, "cpu_used_delta_summation" => 342.0, "capture_interval_name" => "realtime", "mem_vmmemctl_absolute_average" => 0.0, "mem_swapped_absolute_average" => 0.0, "derived_memory_available" => nil, "min_max" => nil, "disk_devicelatency_absolute_average" => nil, "derived_storage_used_unregistered" => nil, "derived_storage_used_unmanaged" => nil, "derived_storage_used_managed" => nil, "derived_storage_snapshot_unregistered" => nil, "derived_storage_snapshot_registered" => nil, "derived_memory_used" => nil, "mem_swaptarget_absolute_average" => 0.0, "derived_storage_vm_count_unregistered" => nil, "derived_storage_mem_managed" => nil, "derived_host_count_on" => 0, "tag_names" => "", "mem_swapout_absolute_average" => 0.0, "disk_queuelatency_absolute_average" => nil, "derived_storage_mem_registered" => nil, "assoc_ids" => {:storages => {:off => [], :on => []}}, "resource_name" => "MIQ-WEBSVR1", "net_usage_rate_average" => 0.0, "mem_vmmemctltarget_absolute_average" => 0.0, "disk_kernellatency_absolute_average" => nil, "derived_storage_snapshot_unmanaged" => nil, "derived_memory_reserved" => nil, "mem_usage_absolute_average" => 5.99, "derived_storage_mem_unmanaged" => nil, "derived_storage_free" => nil, "derived_cpu_available" => nil, "cpu_ready_delta_summation" => 169.0, "derived_storage_total" => nil, "derived_storage_disk_registered" => nil, "cpu_usage_rate_average" => 1.81, "cpu_system_delta_summation" => 2.0},
              {"timestamp" => Time.parse("2011-08-12T21:33:00Z").utc, "capture_interval" => 20, "resource_type" => "VmOrTemplate", "mem_swapin_absolute_average" => 0.0, "derived_storage_vm_count_unmanaged" => nil, "derived_storage_vm_count_registered" => nil, "derived_storage_mem_unregistered" => nil, "sys_uptime_absolute_latest" => 188307.0, "disk_usage_rate_average" => 10.0, "derived_vm_used_disk_storage" => nil, "derived_vm_count_on" => 0, "derived_storage_used_registered" => nil, "derived_storage_snapshot_managed" => nil, "derived_storage_disk_unmanaged" => nil, "derived_host_count_off" => 0, "cpu_usagemhz_rate_average" => 45.0, "derived_storage_vm_count_managed" => nil, "intervals_in_rollup" => nil, "derived_vm_count_off" => 0, "derived_vm_allocated_disk_storage" => nil, "derived_storage_disk_unregistered" => nil, "derived_storage_disk_managed" => nil, "derived_cpu_reserved" => nil, "cpu_wait_delta_summation" => 19028.0, "cpu_used_delta_summation" => 286.0, "capture_interval_name" => "realtime", "mem_vmmemctl_absolute_average" => 0.0, "mem_swapped_absolute_average" => 0.0, "derived_memory_available" => nil, "min_max" => nil, "disk_devicelatency_absolute_average" => nil, "derived_storage_used_unregistered" => nil, "derived_storage_used_unmanaged" => nil, "derived_storage_used_managed" => nil, "derived_storage_snapshot_unregistered" => nil, "derived_storage_snapshot_registered" => nil, "derived_memory_used" => nil, "mem_swaptarget_absolute_average" => 0.0, "derived_storage_vm_count_unregistered" => nil, "derived_storage_mem_managed" => nil, "derived_host_count_on" => 0, "tag_names" => "", "mem_swapout_absolute_average" => 0.0, "disk_queuelatency_absolute_average" => nil, "derived_storage_mem_registered" => nil, "assoc_ids" => {:storages => {:off => [], :on => []}}, "resource_name" => "MIQ-WEBSVR1", "net_usage_rate_average" => 0.0, "mem_vmmemctltarget_absolute_average" => 0.0, "disk_kernellatency_absolute_average" => nil, "derived_storage_snapshot_unmanaged" => nil, "derived_memory_reserved" => nil, "mem_usage_absolute_average" => 5.99, "derived_storage_mem_unmanaged" => nil, "derived_storage_free" => nil, "derived_cpu_available" => nil, "cpu_ready_delta_summation" => 40.0, "derived_storage_total" => nil, "derived_storage_disk_registered" => nil, "cpu_usage_rate_average" => 1.5, "cpu_system_delta_summation" => 2.0}
            ]

            selected = Metric.where(:timestamp => ["2011-08-12T20:33:20Z", "2011-08-12T21:03:00Z", "2011-08-12T21:33:00Z"]).order(:timestamp)
            selected.each_with_index do |p, i|
              ts = p.timestamp.inspect
              expected[i].each do |k, v|
                if v.kind_of?(Float)
                  expect(p.send(k)).to be_within(0.00001).of(v)
                else
                  expect(p.send(k)).to eq(v)
                end
              end
            end
          end
        end
      end
    end
  end
end
