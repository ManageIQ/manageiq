require "spec_helper"

#$log.level = Rails.logger.level = 0

describe Metric do
  before(:each) do
    MiqRegion.seed

    guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  context "as vmware" do
    require File.expand_path(File.join(File.dirname(__FILE__), %w{.. tools vim_data vim_data_test_helper}))

    before :each do
      @ems_vmware = FactoryGirl.create(:ems_vmware, :zone => @zone)
    end

    context "with enabled and disabled targets" do
      before(:each) do
        storages = []
        2.times { storages << FactoryGirl.create(:storage_target_vmware) }

        @vmware_clusters = []
        2.times do
          cluster = FactoryGirl.create(:cluster_target)
          @vmware_clusters << cluster
          @ems_vmware.ems_clusters << cluster
        end

        6.times do |n|
          host = FactoryGirl.create(:host_target_vmware)
          @ems_vmware.hosts << host

          @vmware_clusters[n / 2].hosts << host if n < 4
          host.storages << storages[n / 3]
        end

        MiqQueue.delete_all
      end

      context "executing capture_targets" do
        it "should find enabled targets" do
          targets = Metric::Targets.capture_targets
          assert_infra_targets_enabled targets, %w{VmVmware Host Host VmVmware Host Storage}
        end

        it "should find enabled targets excluding storages" do
          targets = Metric::Targets.capture_targets(nil, :exclude_storages => true)
          assert_infra_targets_enabled targets, %w{VmVmware Host Host VmVmware Host}
        end

        it "should find enabled targets excluding vms" do
          targets = Metric::Targets.capture_targets(nil, :exclude_vms => true)
          assert_infra_targets_enabled targets, %w{Host Host Host Storage}
        end

        it "should find enabled targets excluding vms and storages" do
          targets = Metric::Targets.capture_targets(nil, :exclude_storages => true, :exclude_vms => true)
          assert_infra_targets_enabled targets, %w{Host Host Host}
        end
      end

      context "executing perf_capture_timer" do
        before(:each) do
          VMDB::Config.any_instance.stub(:config).and_return({:performance => {:history => {:initial_capture_days => 7}}})
          Metric::Capture.perf_capture_timer
        end

        it "should queue up enabled targets" do
          MiqQueue.count.should == 47

          expected_targets = Metric::Targets.capture_targets
          expected = expected_targets.collect do |t|
            # Storage is hourly only
            # Non-storage historical is expecting 7 days back, plus partial day = 8
            t.is_a?(Storage) ? [t, "hourly"] : [[t, "realtime"], [t, "historical"] * 8]
          end.flatten

          selected = MiqQueue.all(:conditions => {:method_name => "perf_capture"}, :order => :id).collect do |q|
            [Object.const_get(q.class_name).find(q.instance_id), q.args.first]
          end.flatten

          selected.should == expected
        end

        context "executing capture_targets for realtime targets with parent objects" do
          before(:each) do
            @expected_targets = Metric::Targets.capture_targets
          end

          it "should create tasks and queue callbacks" do
            @vmware_clusters.each do |cluster|
              expected_hosts = cluster.hosts.select {|h| @expected_targets.include?(h)}
              next if expected_hosts.empty?

              task = MiqTask.find_by_name("Performance rollup for EmsCluster:#{cluster.id}")
              task.should_not be_nil
              task.context_data[:targets].sort.should == cluster.hosts.collect {|h| "Host:#{h.id}"}.sort

              expected_hosts.each do |host|
                messages = MiqQueue.all(:conditions => {:class_name => "Host", :instance_id => host.id}).select {|m| m.args.first == "realtime"}
                messages.each do |m|
                  m.miq_callback.should_not be_nil
                  m.miq_callback[:method_name].should == :perf_capture_callback
                  m.miq_callback[:args].should == [[task.id]]

                  m.delivered("ok", "Message delivered successfully", nil)
                end
              end

              task.reload
              task.state.should == "Finished"

              message = MiqQueue.first(:conditions => {:method_name => "perf_rollup_range", :class_name => "EmsCluster", :instance_id => cluster.id})
              message.should_not be_nil
              message.args.should == [task.context_data[:start], task.context_data[:end], task.context_data[:interval], nil]
            end
          end

          it "calling perf_capture_timer when existing capture messages are on the queue should merge messages and append new task id to cb args" do
            Metric::Capture.perf_capture_timer
            @vmware_clusters.each do |cluster|
              expected_hosts = cluster.hosts.select {|h| @expected_targets.include?(h)}
              next if expected_hosts.empty?

              tasks = MiqTask.all(:conditions => {:name => "Performance rollup for EmsCluster:#{cluster.id}"}, :order => "id DESC")
              tasks.length.should == 2
              tasks.each do |task|
                task.context_data[:targets].sort.should == cluster.hosts.collect {|h| "Host:#{h.id}"}.sort
              end

              task_ids = tasks.collect(&:id)

              expected_hosts.each do |host|
                messages = MiqQueue.all(:conditions => {:class_name => "Host", :instance_id => host.id}).select {|m| m.args.first == "realtime"}
                host.update_attribute(:last_perf_capture_on, 1.minute.from_now.utc)
                messages.each do |m|
                  next if m.miq_callback[:args].blank?

                  m.miq_callback.should_not be_nil
                  m.miq_callback[:method_name].should == :perf_capture_callback
                  m.miq_callback[:args].first.sort.should == task_ids.sort

                  status, message, result = m.deliver
                  m.delivered(status, message, result)
                end
              end

              tasks.each do |task|
                task.reload
                task.state.should == "Finished"
              end
            end
          end

          it "calling perf_capture_timer when existing capture messages are on the queue in dequeue state should NOT merge" do
            messages = MiqQueue.all(:conditions => {:class_name => "Host"}).select {|m| m.args.first == "realtime"}
            messages.each {|m| m.update_attribute(:state, "dequeue")}

            Metric::Capture.perf_capture_timer

            messages = MiqQueue.all(:conditions => {:class_name => "Host"}).select {|m| m.args.first == "realtime"}
            messages.each {|m| m.lock_version.should == 1}
          end

          it "calling perf_capture_timer a second time should create another task with the correct time window" do
            Metric::Capture.perf_capture_timer

            @vmware_clusters.each do |cluster|
              expected_hosts = cluster.hosts.select {|h| @expected_targets.include?(h)}
              next if expected_hosts.empty?

              tasks = MiqTask.all(:conditions => {:name => "Performance rollup for EmsCluster:#{cluster.id}"}, :order => "id")
              tasks.length.should == 2

              t1, t2 = tasks
              t2.context_data[:start].should == t1.context_data[:end]
            end
          end
        end
      end

      context "executing perf_capture_gap" do
        before(:each) do
          t = Time.now.utc
          Metric::Capture.perf_capture_gap(t - 7.days, t - 5.days)
        end

        it "should queue up enabled targets for historical" do
          MiqQueue.count.should == 10

          expected_targets = Metric::Targets.capture_targets(nil, :exclude_storages => true)
          expected = expected_targets.collect { |t| [t, "historical"] * 2 }.flatten # Vm, Host, Host, Vm, Host

          selected = MiqQueue.all(:order => :id).collect do |q|
            [Object.const_get(q.class_name).find(q.instance_id), q.args.first]
          end.flatten

          selected.should == expected
        end
      end

      context "executing perf_capture_realtime_now" do
        before(:each) do
          @vm = Vm.first
          @vm.perf_capture_realtime_now
        end

        it "should queue up realtime capture for vm" do
          MiqQueue.count.should == 1

          msg = MiqQueue.first
          msg.priority.should    == MiqQueue::HIGH_PRIORITY
          msg.instance_id.should == @vm.id
          msg.class_name.should  == "VmVmware"
        end

        context "with an existing queue item at a lower priority" do
          before(:each) do
            MiqQueue.first.update_attribute(:priority, MiqQueue::NORMAL_PRIORITY)
            @vm.perf_capture_realtime_now
          end

          it "should raise the priority of the existing queue item" do
            MiqQueue.count.should == 1

            msg = MiqQueue.first
            msg.priority.should    == MiqQueue::HIGH_PRIORITY
            msg.instance_id.should == @vm.id
            msg.class_name.should  == "VmVmware"
          end
        end

        context "with an existing queue item at a higher priority" do
          before(:each) do
            MiqQueue.first.update_attribute(:priority, MiqQueue::MAX_PRIORITY)
            @vm.perf_capture_realtime_now
          end

          it "should not lower the priority of the existing queue item" do
            MiqQueue.count.should == 1

            msg = MiqQueue.first
            msg.priority.should    == MiqQueue::MAX_PRIORITY
            msg.instance_id.should == @vm.id
            msg.class_name.should  == "VmVmware"
          end
        end
      end
    end

    context "with a vm" do
      before(:each) do
        @vm = FactoryGirl.create(:vm_perf, :ext_management_system => @ems_vmware)
      end

      context "and a fake vim handle" do
        before(:each) do
          EmsVmware.any_instance.stub(:connect).and_return(FakeMiqVimHandle.new)
          EmsVmware.any_instance.stub(:disconnect).and_return(true)
        end

        context "collecting vm realtime data" do
          before(:each) do
            @counters_by_mor, @counter_values_by_mor_and_ts = @vm.perf_collect_metrics('realtime')
          end

          it "should have collected counters and values" do
            @counters_by_mor.length.should              == 1
            @counter_values_by_mor_and_ts.length.should == 1

            counters = @counters_by_mor[@vm.ems_ref_obj]
            counters.length.should == 18

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

            selected = counters.values.collect { |c| c.values_at(:capture_interval_name, :counter_key, :instance) }.sort
            selected.should == expected

            counter_values = @counter_values_by_mor_and_ts[@vm.ems_ref_obj]
            timestamps = counter_values.keys.sort
            timestamps.first.should == "2011-08-12T20:33:20Z"
            timestamps.last.should  == "2011-08-12T21:33:00Z"

            # Check every timestamp is present
            counter_values.length.should == 180

            ts = timestamps.first
            until ts > timestamps.last do
              counter_values.has_key?(ts).should be_true
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

            selected.should == expected
          end
        end

        context "capturing vm realtime data" do
          before(:each) do
            @alarm_event = "vm_perf_complete"
            @vm.perf_capture('realtime')
          end

          it "should have collected performances" do
            # Check Vm record was updated
            @vm.last_perf_capture_on.utc.iso8601.should == "2011-08-12T21:33:00Z"

            # Check performances
            Metric.count.should == 180

            # Check every timestamp is present; performance realtime timestamps
            #   are to the nearest 20 second interval
            ts = "2011-08-12T20:33:20Z"
            Metric.all(:order => :timestamp).each do |p|
              p_ts = p.timestamp.utc
              p_ts.iso8601.should == ts
              ts = (p_ts + 20.seconds).iso8601
            end

            # Check a few specific values
            expected = [
              {"timestamp" => Time.parse("2011-08-12T20:33:20Z").utc, "capture_interval" => 20, "resource_type" => "VmOrTemplate", "mem_swapin_absolute_average" => 0.0, "derived_storage_vm_count_unmanaged" => nil, "derived_storage_vm_count_registered" => nil, "derived_storage_mem_unregistered" => nil, "sys_uptime_absolute_latest" => 184728.0, "disk_usage_rate_average" => 8.0, "derived_vm_used_disk_storage" => nil, "derived_vm_count_on" => 0, "derived_storage_used_registered" => nil, "derived_storage_snapshot_managed" => nil, "derived_storage_disk_unmanaged" => nil, "derived_host_count_off" => 0, "cpu_usagemhz_rate_average" => 41.0, "derived_storage_vm_count_managed" => nil, "intervals_in_rollup" => nil, "derived_vm_count_off" => 0, "derived_vm_allocated_disk_storage" => nil, "derived_storage_disk_unregistered" => nil, "derived_storage_disk_managed" => nil, "derived_cpu_reserved" => nil, "cpu_wait_delta_summation" => 19048.0, "cpu_used_delta_summation" => 265.0, "capture_interval_name" => "realtime", "mem_vmmemctl_absolute_average" => 0.0, "mem_swapped_absolute_average" => 0.0, "derived_memory_available" => 0.0, "min_max" => nil, "disk_devicelatency_absolute_average" => nil, "derived_storage_used_unregistered" => nil, "derived_storage_used_unmanaged" => nil, "derived_storage_used_managed" => nil, "derived_storage_snapshot_unregistered" => nil, "derived_storage_snapshot_registered" => nil, "derived_memory_used" => nil, "mem_swaptarget_absolute_average" => 0.0, "derived_storage_vm_count_unregistered" => nil, "derived_storage_mem_managed" => nil, "derived_host_count_on" => 0, "tag_names" => "", "mem_swapout_absolute_average" => 0.0, "disk_queuelatency_absolute_average" => nil, "derived_storage_mem_registered" => nil, "assoc_ids" => {:storages => {:off => [], :on => []}}, "resource_name" => "MIQ-WEBSVR1", "net_usage_rate_average" => 0.0, "mem_vmmemctltarget_absolute_average" => 0.0, "disk_kernellatency_absolute_average" => nil, "derived_storage_snapshot_unmanaged" => nil, "derived_memory_reserved" => nil, "mem_usage_absolute_average" => 3.99, "derived_storage_mem_unmanaged" => nil, "derived_storage_free" => nil, "derived_cpu_available" => 0.0, "cpu_ready_delta_summation" => 40.0, "derived_storage_total" => nil, "derived_storage_disk_registered" => nil, "cpu_usage_rate_average" => 1.38, "cpu_system_delta_summation" => 2.0},
              {"timestamp" => Time.parse("2011-08-12T21:03:00Z").utc, "capture_interval" => 20, "resource_type" => "VmOrTemplate", "mem_swapin_absolute_average" => 0.0, "derived_storage_vm_count_unmanaged" => nil, "derived_storage_vm_count_registered" => nil, "derived_storage_mem_unregistered" => nil, "sys_uptime_absolute_latest" => 186508.0, "disk_usage_rate_average" => 8.0, "derived_vm_used_disk_storage" => nil, "derived_vm_count_on" => 0, "derived_storage_used_registered" => nil, "derived_storage_snapshot_managed" => nil, "derived_storage_disk_unmanaged" => nil, "derived_host_count_off" => 0, "cpu_usagemhz_rate_average" => 54.0, "derived_storage_vm_count_managed" => nil, "intervals_in_rollup" => nil, "derived_vm_count_off" => 0, "derived_vm_allocated_disk_storage" => nil, "derived_storage_disk_unregistered" => nil, "derived_storage_disk_managed" => nil, "derived_cpu_reserved" => nil, "cpu_wait_delta_summation" => 18928.0, "cpu_used_delta_summation" => 342.0, "capture_interval_name" => "realtime", "mem_vmmemctl_absolute_average" => 0.0, "mem_swapped_absolute_average" => 0.0, "derived_memory_available" => 0.0, "min_max" => nil, "disk_devicelatency_absolute_average" => nil, "derived_storage_used_unregistered" => nil, "derived_storage_used_unmanaged" => nil, "derived_storage_used_managed" => nil, "derived_storage_snapshot_unregistered" => nil, "derived_storage_snapshot_registered" => nil, "derived_memory_used" => nil, "mem_swaptarget_absolute_average" => 0.0, "derived_storage_vm_count_unregistered" => nil, "derived_storage_mem_managed" => nil, "derived_host_count_on" => 0, "tag_names" => "", "mem_swapout_absolute_average" => 0.0, "disk_queuelatency_absolute_average" => nil, "derived_storage_mem_registered" => nil, "assoc_ids" => {:storages => {:off => [], :on => []}}, "resource_name" => "MIQ-WEBSVR1", "net_usage_rate_average" => 0.0, "mem_vmmemctltarget_absolute_average" => 0.0, "disk_kernellatency_absolute_average" => nil, "derived_storage_snapshot_unmanaged" => nil, "derived_memory_reserved" => nil, "mem_usage_absolute_average" => 5.99, "derived_storage_mem_unmanaged" => nil, "derived_storage_free" => nil, "derived_cpu_available" => 0.0, "cpu_ready_delta_summation" => 169.0, "derived_storage_total" => nil, "derived_storage_disk_registered" => nil, "cpu_usage_rate_average" => 1.81, "cpu_system_delta_summation" => 2.0},
              {"timestamp" => Time.parse("2011-08-12T21:33:00Z").utc, "capture_interval" => 20, "resource_type" => "VmOrTemplate", "mem_swapin_absolute_average" => 0.0, "derived_storage_vm_count_unmanaged" => nil, "derived_storage_vm_count_registered" => nil, "derived_storage_mem_unregistered" => nil, "sys_uptime_absolute_latest" => 188307.0, "disk_usage_rate_average" => 10.0, "derived_vm_used_disk_storage" => nil, "derived_vm_count_on" => 0, "derived_storage_used_registered" => nil, "derived_storage_snapshot_managed" => nil, "derived_storage_disk_unmanaged" => nil, "derived_host_count_off" => 0, "cpu_usagemhz_rate_average" => 45.0, "derived_storage_vm_count_managed" => nil, "intervals_in_rollup" => nil, "derived_vm_count_off" => 0, "derived_vm_allocated_disk_storage" => nil, "derived_storage_disk_unregistered" => nil, "derived_storage_disk_managed" => nil, "derived_cpu_reserved" => nil, "cpu_wait_delta_summation" => 19028.0, "cpu_used_delta_summation" => 286.0, "capture_interval_name" => "realtime", "mem_vmmemctl_absolute_average" => 0.0, "mem_swapped_absolute_average" => 0.0, "derived_memory_available" => 0.0, "min_max" => nil, "disk_devicelatency_absolute_average" => nil, "derived_storage_used_unregistered" => nil, "derived_storage_used_unmanaged" => nil, "derived_storage_used_managed" => nil, "derived_storage_snapshot_unregistered" => nil, "derived_storage_snapshot_registered" => nil, "derived_memory_used" => nil, "mem_swaptarget_absolute_average" => 0.0, "derived_storage_vm_count_unregistered" => nil, "derived_storage_mem_managed" => nil, "derived_host_count_on" => 0, "tag_names" => "", "mem_swapout_absolute_average" => 0.0, "disk_queuelatency_absolute_average" => nil, "derived_storage_mem_registered" => nil, "assoc_ids" => {:storages => {:off => [], :on => []}}, "resource_name" => "MIQ-WEBSVR1", "net_usage_rate_average" => 0.0, "mem_vmmemctltarget_absolute_average" => 0.0, "disk_kernellatency_absolute_average" => nil, "derived_storage_snapshot_unmanaged" => nil, "derived_memory_reserved" => nil, "mem_usage_absolute_average" => 5.99, "derived_storage_mem_unmanaged" => nil, "derived_storage_free" => nil, "derived_cpu_available" => 0.0, "cpu_ready_delta_summation" => 40.0, "derived_storage_total" => nil, "derived_storage_disk_registered" => nil, "cpu_usage_rate_average" => 1.5, "cpu_system_delta_summation" => 2.0}
            ]

            selected = Metric.find_all_by_timestamp(["2011-08-12T20:33:20Z", "2011-08-12T21:03:00Z", "2011-08-12T21:33:00Z"], :order => :timestamp)
            selected.each_with_index do |p, i|
              ts = p.timestamp.inspect
              expected[i].each do |k, v|
                if v.kind_of?(Float)
                  p.send(k).should be_within(0.00001).of(v)
                else
                  p.send(k).should == v
                end
              end
            end

            # perf_rollup is queued unconditionally
            # evaluate_alerts is queued only if there's an alert defined for "vm_perf_complete"
            q_all = MiqQueue.all(:order => :id)

            if MiqAlert.alarm_has_alerts?(@alarm_event)
              MiqQueue.count.should == 3
              q = q_all.shift
              q.class_name.should == "MiqAlert"
              q.method_name.should == "evaluate_alerts"
              q.args.should == [["VmVmware", @vm.id], @alarm_event, {}]
            else
              MiqQueue.count.should == 2
            end
            assert_queue_items_are_hourly_rollups(q_all, "2011-08-12T20:00:00Z", @vm.id, "VmVmware")
          end

          it "should normalize percent values > 100 to 100" do
            pending "Need to be updated due to source data change"
            expected = [
              {"timestamp" => Time.parse("2010-04-14T22:50:20Z").utc, "cpu_usage_rate_average" => 99.99},
              {"timestamp" => Time.parse("2010-04-14T22:50:40Z").utc, "cpu_usage_rate_average" => 100.0}
            ]

            selected = Metric.find_all_by_timestamp("2010-04-14T22:50:20Z", "2010-04-14T22:50:40Z")
            selected.each_with_index do |p, i|
              expected[i].each { |k, v| p.send(k).should be_within(0.01).of(v) }
            end
          end

          context "maintains_value_for_duration?" do
            before(:each) do
              Timecop.travel(Time.parse("2010-04-14T22:52:00Z"))
            end

            after(:each) do
              Timecop.return
            end

            it "will return correct values" do
              pending "Need to be updated due to source data change"
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "=", :value => 3.51, :duration => 20.minutes).should_not be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "=", :value => 3.5, :duration => 10.minutes, :percentage => 5).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => ">", :value => 3.0, :duration => 60.minutes).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => ">", :value => 3.3, :duration => 15.minutes, :percentage => 50).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => ">=", :value => 3.5, :duration => 11.minutes).should_not be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 3.minutes).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<=", :value => 100.0, :duration => 8.minutes).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<=", :value => 4.0, :duration => 45.minutes, :percentage => 50).should be_true
              # Pass :starting_on
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<=", :value => 4.0, :duration => 10.minutes, :starting_on => (Time.now.utc - 15.minutes), :percentage => 50).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => ">", :value => 4.0, :duration => 2.minutes, :starting_on => (Time.now.utc - 2.minutes), :percentage => 50).should be_false
            end
          end

          context "maintains_value_for_duration? with overlap and slope" do
            before(:each) do
              Timecop.travel(Time.parse("2010-04-14T22:07:20Z"))
            end

            after(:each) do
              Timecop.return
            end

            it "will return correct values" do
              pending "Need to be updated due to source data change"
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:20Z".to_time)).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:20Z".to_time), :trend_direction => "none").should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:20Z".to_time), :trend_direction => "up").should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:20Z".to_time), :trend_direction => "down").should be_false

              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:40Z".to_time)).should be_false
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:40Z".to_time), :trend_direction => "none").should be_false
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:40Z".to_time), :trend_direction => "up").should be_false
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:40Z".to_time), :trend_direction => "down").should be_false

              # Approximate stasrting_on ts
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:19Z".to_time)).should be_true
              @vm.performances_maintains_value_for_duration?(:column => "cpu_usage_rate_average", :operator => "<", :value => 3.5, :duration => 2.minutes, :starting_on => ("2010-04-14T22:04:21Z".to_time)).should be_false
            end
          end
        end
      end

      context "queueing up realtime rollups to parent" do
        before(:each) do
          MiqQueue.delete_all
          @vm.perf_rollup_to_parent("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        end

        it "should have queued rollups for vm hourly" do
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "VmVmware")
        end

        context "twice" do
          before(:each) do
            @vm.perf_rollup_to_parent("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
          end

          it "should have one set of queued rollups" do
            q_all = MiqQueue.all(:order => :id)
            q_all.length.should == 2
            assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "VmVmware")
          end
        end
      end

      context "executing perf_capture_now?" do
        before(:each) do
          VMDB::Config.any_instance.stub(:config).and_return({:performance => {:capture_threshold => {:vm => 10}, :capture_threshold_with_alerts => {:vm => 2}}})
        end

        it "without alerts assigned" do
          MiqAlert.stub(:target_needs_realtime_capture?).and_return(false)
          assert_perf_capture_now @vm, :without_alerts
        end

        it "with alerts assigned" do
          MiqAlert.stub(:target_needs_realtime_capture?).and_return(true)
          assert_perf_capture_now @vm, :with_alerts
        end
      end
    end

    context "with a small environment and time_profile" do
      before(:each) do
        @vm1 = FactoryGirl.create(:vm_vmware)
        @vm2 = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 4096, :numvcpus => 2))
        @host1 = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 8124, :logical_cpus => 1, :cpu_speed => 9576), :vms => [@vm1])
        @host2 = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 8124, :logical_cpus => 1, :cpu_speed => 9576))

        @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host1
        @ems_cluster.hosts << @host2

        @time_profile = FactoryGirl.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "with Vm realtime performances" do
        before(:each) do
          cases = [
            "2010-04-14T20:52:30Z", 100.0,
            "2010-04-14T21:51:10Z", 1.0,
            "2010-04-14T21:51:30Z", 2.0,
            "2010-04-14T21:51:50Z", 4.0,
            "2010-04-14T21:52:10Z", 8.0,
            "2010-04-14T21:52:30Z", 15.0,
            "2010-04-14T22:52:30Z", 100.0,
          ]
          cases.each_slice(2) do |t, v|
            @vm1.metrics << FactoryGirl.create(:metric_vm_rt,
              :timestamp                  => t,
              :cpu_usage_rate_average     => v,
              :cpu_ready_delta_summation  => v * 1000, # Multiply by a factor of 1000 to maake it more realistic and enable testing virtual col v_pct_cpu_ready_delta_summation
              :sys_uptime_absolute_latest => v
            )
          end
        end

        it "should find the correct rows" do
          Metric::Finders.hour_to_range("2010-04-14T21:00:00Z").should == ["2010-04-14T21:00:00Z", "2010-04-14T21:59:59Z"]
          Metric::Finders.find_all_by_hour(@vm1, "2010-04-14T21:00:00Z", 'realtime').should == @vm1.metrics.sort_by(&:timestamp)[1..5]
        end

        context "calling perf_rollup to hourly on the Vm" do
          before(:each) do
            @vm1.perf_rollup("2010-04-14T21:00:00Z", 'hourly')
          end

          it "should rollup Vm realtime into Vm hourly rows correctly" do
            MetricRollup.hourly.count.should == 1
            perf = MetricRollup.hourly.first

            perf.resource_type.should         == 'VmOrTemplate'
            perf.resource_id.should           == @vm1.id
            perf.capture_interval_name.should == 'hourly'
            perf.timestamp.iso8601.should     == "2010-04-14T21:00:00Z"

            perf.cpu_usage_rate_average.should          == 6.0
            perf.cpu_ready_delta_summation.should       == 30000.0
            perf.v_pct_cpu_ready_delta_summation.should == 30.0
            perf.sys_uptime_absolute_latest.should      == 15.0

            perf.abs_max_cpu_usage_rate_average_value.should == 15.0
            perf.abs_max_cpu_usage_rate_average_timestamp.utc.iso8601.should == "2010-04-14T21:52:30Z"

            perf.abs_min_cpu_usage_rate_average_value == 1.0
            perf.abs_min_cpu_usage_rate_average_timestamp.utc.iso8601 == "2010-04-14T21:51:10Z"
          end
        end
      end

      context "with Vm hourly performances" do
        before(:each) do
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
            @vm1.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
              :timestamp                  => t,
              :cpu_usage_rate_average     => v,
              :cpu_ready_delta_summation  => v * 10000,
              :sys_uptime_absolute_latest => v,
              :min_max => {
                :abs_max_cpu_usage_rate_average_value     => v,
                :abs_max_cpu_usage_rate_average_timestamp => Time.parse(t) + 20.seconds,
                :abs_min_cpu_usage_rate_average_value     => v,
                :abs_min_cpu_usage_rate_average_timestamp => Time.parse(t) + 40.seconds,
              }
            )
          end
        end

        it "should find the correct rows" do
          Metric::Finders.day_to_range("2010-04-14T00:00:00Z", @time_profile).should == ["2010-04-14T00:00:00Z", "2010-04-14T23:59:59Z"]
          Metric::Finders.find_all_by_day(@vm1, "2010-04-14T00:00:00Z", 'hourly', @time_profile).should match_array @vm1.metric_rollups.sort_by(&:timestamp)[1..5]
        end

        it "should find multiple resource types" do
          @host1.metric_rollups << FactoryGirl.create(:metric_rollup_host_hr,
                                                      :resource  => @host1,
                                                      :timestamp => "2010-04-14T22:00:00Z")
          metrics = Metric::Finders.find_all_by_day([@vm1, @host1], "2010-04-14T00:00:00Z", 'hourly', @time_profile)
          metrics.collect { |m| m.resource_type }.uniq.sort.should == %w(VmOrTemplate Host).uniq.sort
        end

        context "calling perf_rollup to daily on the Vm" do
          before(:each) do
            @vm1.perf_rollup("2010-04-14T00:00:00Z", 'daily', @time_profile.id)
          end

          it "should rollup Vm hourly into Vm daily rows correctly" do
            MetricRollup.daily.count.should == 1
            perf = MetricRollup.daily.first

            perf.resource_type.should         == 'VmOrTemplate'
            perf.resource_id.should           == @vm1.id
            perf.capture_interval_name.should == 'daily'
            perf.timestamp.iso8601.should     == "2010-04-14T00:00:00Z"
            perf.time_profile_id.should       == @time_profile.id

            perf.cpu_usage_rate_average.should          == 6.0
            perf.cpu_ready_delta_summation.should       == 60000.0 # actually uses average
            perf.v_pct_cpu_ready_delta_summation.should == 1.7
            perf.sys_uptime_absolute_latest.should      == 6.0     # actually uses average

            perf.max_cpu_usage_rate_average.should                           == 15.0
            perf.abs_max_cpu_usage_rate_average_value.should                 == 15.0
            perf.abs_max_cpu_usage_rate_average_timestamp.utc.iso8601.should == "2010-04-14T22:00:20Z"

            perf.min_cpu_usage_rate_average.should                           == 1.0
            perf.abs_min_cpu_usage_rate_average_value.should                 == 1.0
            perf.abs_min_cpu_usage_rate_average_timestamp.utc.iso8601.should == "2010-04-14T18:00:40Z"
          end
        end

        context "calling perf_rollup_range to daily on the Vm" do
          before(:each) do
            @vm1.perf_rollup_range("2010-04-13T00:00:00Z", "2010-04-15T00:00:00Z", 'daily', @time_profile.id)
          end

          it "should rollup Vm hourly into Vm daily rows correctly" do
            perfs = MetricRollup.daily.all
            perfs.length.should == 3
            perfs.collect { |r| r.timestamp.iso8601 }.sort.should == ["2010-04-13T00:00:00Z", "2010-04-14T00:00:00Z", "2010-04-15T00:00:00Z"]
          end
        end

        context "with Vm daily performances" do
          before(:each) do
            @perf = FactoryGirl.create(:metric_rollup_vm_daily,
              :timestamp    => "2010-04-14T00:00:00Z",
              :time_profile => @time_profile
            )
          end

          it "VimPerformanceDaily.find should return existing daily performances when a time_profile is passed" do
            rec = VimPerformanceDaily.find(:all, :ext_options => {:time_profile => @time_profile})
            rec.should == [@perf]
          end

          it "VimPerformanceDaily.find should return existing daily performances when a time_profile is not passed, but an associated tz is" do
            rec = VimPerformanceDaily.find(:all, :ext_options => {:tz => "UTC"})
            rec.should == [@perf]
          end

          it "VimPerformanceDaily.find should return existing daily performances when defaulting to UTC time zone" do
            rec = VimPerformanceDaily.find(:all)
            rec.should == [@perf]
          end

          it "VimPerformanceDaily.find should return an empty array when a time_profile is not passed" do
            rec = VimPerformanceDaily.find(:all, :ext_options => {:tz => "Alaska"})
            rec.length.should == 0
          end
        end

        context "testing operating ranges and right-sizing with Vm daily performances for several days" do
          before(:each) do
            Timecop.travel(Time.parse("2010-05-01T00:00:00Z"))
            cases = [
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
                vm.metric_rollups << FactoryGirl.create(:metric_rollup_vm_daily,
                  :timestamp                  => t,
                  :cpu_usage_rate_average     => cpu,
                  :mem_usage_absolute_average => mem,
                  :min_max => {
                    :max_cpu_usage_rate_average     => cpu,
                    :max_mem_usage_absolute_average => mem,
                  },
                  :time_profile => @time_profile
                )
              end
            end
          end

          after(:each) do
            Timecop.return
          end

          it "should calculate the correct normal operating range values" do
            @vm1.max_cpu_usage_rate_average_avg_over_time_period.should     be_within(0.001).of(13.692)
            @vm1.max_mem_usage_absolute_average_avg_over_time_period.should be_within(0.001).of(33.085)
          end

          it "should calculate the correct right-size values" do
            VmVmware.stub(:mem_recommendation_minimum).and_return(0)

            @vm1.recommended_vcpus.should       == 1
            @vm1.recommended_mem.should         == 4
            @vm1.overallocated_vcpus_pct.should == 0
            @vm1.overallocated_mem_pct.should   == 0

            @vm2.recommended_vcpus.should       == 1
            @vm2.recommended_mem.should         == 1356
            @vm2.overallocated_vcpus_pct.should be_within(0.01).of(50.0)
            @vm2.overallocated_mem_pct.should   be_within(0.01).of(66.9)
          end
        end

        context "and Host realtime performances" do
          before(:each) do
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
              @host1.metrics << FactoryGirl.create(:metric_host_rt,
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
              @host2.metrics << FactoryGirl.create(:metric_host_rt,
                :timestamp                  => t,
                :cpu_usage_rate_average     => v,
                :cpu_usagemhz_rate_average  => v,
                :sys_uptime_absolute_latest => v
              )
            end
          end

          context "calling perf_rollup to hourly on the Host" do
            before(:each) do
              @host1.perf_rollup("2010-04-14T21:00:00Z", 'hourly')
            end

            it "should rollup Host realtime and Vm hourly into Host hourly rows correctly" do
              MetricRollup.hourly.count(:conditions => {:resource_type => 'Host', :resource_id => @host1.id}).should == 1
              perf = MetricRollup.hourly.first(:conditions => {:resource_type => 'Host', :resource_id => @host1.id})

              perf.resource_type.should         == 'Host'
              perf.resource_id.should           == @host1.id
              perf.capture_interval_name.should == 'hourly'
              perf.timestamp.iso8601.should     == "2010-04-14T21:00:00Z"

              perf.cpu_usage_rate_average.should          == 12.0    # pulled from Host realtime
              perf.cpu_ready_delta_summation.should       == 80000.0 # pulled from Vm hourly
              perf.v_pct_cpu_ready_delta_summation.should == 2.2
              perf.sys_uptime_absolute_latest.should      == 30.0    # pulled from Host realtime

              # NOTE: min / max / burst are only pulled in from Vm realtime.
            end
          end

          context "calling perf_rollup_range to realtime on the parent Cluster" do
            before(:each) do
              @ems_cluster.perf_rollup_range("2010-04-14T21:51:20Z", "2010-04-14T21:52:40Z", 'realtime')
            end

            it "should rollup Host realtime Cluster realtime rows correctly" do
              Metric.count(:conditions => {:resource_type => 'EmsCluster', :resource_id => @ems_cluster.id}).should == 5
              perfs = Metric.all(:conditions => {:resource_type => 'EmsCluster', :resource_id => @ems_cluster.id}, :order => "timestamp")

              perfs[0].resource_type.should         == 'EmsCluster'
              perfs[0].resource_id.should           == @ems_cluster.id
              perfs[0].capture_interval_name.should == 'realtime'
              perfs[0].timestamp.iso8601.should     == "2010-04-14T21:51:20Z"

              perfs[0].cpu_usage_rate_average.should     == 2.5 # pulled from Host realtime
              perfs[0].cpu_usagemhz_rate_average.should  == 5.0 # pulled from Host realtime
              perfs[0].sys_uptime_absolute_latest.should == 3.0 # pulled from Host realtime
              perfs[0].derived_cpu_available.should      == 19152

              perfs[2].cpu_usage_rate_average.should     == 12.0  # pulled from Host realtime
              perfs[2].cpu_usagemhz_rate_average.should  == 24.0  # pulled from Host realtime
              perfs[2].sys_uptime_absolute_latest.should == 16.0  # pulled from Host realtime
              perfs[2].derived_cpu_available.should      == 19152

              perfs[3].cpu_usage_rate_average.should     == 24.0  # pulled from Host realtime
              perfs[3].cpu_usagemhz_rate_average.should  == 48.0  # pulled from Host realtime
              perfs[3].sys_uptime_absolute_latest.should == 32.0  # pulled from Host realtime
              perfs[3].derived_cpu_available.should      == 19152
            end
          end

          context "executing perf_rollup_gap_queue" do
            before(:each) do
              @args = [2.days.ago.utc, Time.now.utc, 'daily', @time_profile.id]
              Metric::Rollup.perf_rollup_gap_queue(*@args)
            end

            it "should queue up perf_rollup_gap" do
              q_all = MiqQueue.all(:order => :class_name)
              q_all.length.should == 1

              expected = {
                :args        => @args,
                :class_name  => "Metric::Rollup",
                :method_name => "perf_rollup_gap",
                :role        => nil
              }

              q_all[0].should have_attributes(expected)
            end
          end

          context "executing perf_rollup_gap" do
            before(:each) do
              @args = [2.days.ago.utc, Time.now.utc, 'daily', @time_profile.id]
              Metric::Rollup.perf_rollup_gap(*@args)
            end

            it "should queue up the rollups" do
              MiqQueue.count.should == 3

              [@host1, @host2, @vm1].each do |ci|
                message = MiqQueue.where(:class_name => ci.class.name, :instance_id => ci.id).first
                message.should have_attributes(:method_name => "perf_rollup_range", :args => @args)
              end
            end
          end

          context "calling get_performance_metric" do
            it "should return the correct value(s)" do
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"]).should == [100.0, 2.0, 4.0, 8.0, 16.0, 30.0, 100.0]
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"], :avg).should be_within(0.0001).of(37.1428571428571)
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"], :min).should == 2.0
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z", "2010-04-14T22:52:40Z"], :max).should == 100.0

              # Test supported formats of time range
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, ["2010-04-14T20:52:40Z".to_time.utc, "2010-04-14T22:52:40Z".to_time.utc], :min).should == 2.0
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, "2010-04-14T20:52:40Z", :max).should == 100.0
              @host1.get_performance_metric(:realtime, :cpu_usage_rate_average, "2010-04-14T20:52:40Z".to_time.utc, :max).should == 100.0
            end
          end
        end
      end
    end

    context "with a full rollup chain and time profile" do
      before(:each) do
        @host = FactoryGirl.create(:host, :ext_management_system => @ems_vmware)
        @vm = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems_vmware, :host => @host)
        @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems_vmware)
        @ems_cluster.hosts << @host

        @time_profile = FactoryGirl.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "calling perf_rollup_to_parent" do
        it "should queue up from Vm realtime to Vm hourly" do
          @vm.perf_rollup_to_parent('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 1
          assert_queue_item_rollup_chain(q_all[0], @vm, 'hourly')
        end

        it "should queue up from Host realtime to Host hourly" do
          @host.perf_rollup_to_parent('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 1
          # assert_queue_item_rollup_chain(q_all[0], @ems_cluster, 'realtime')
          # assert_queue_item_rollup_chain(q_all[1], @host, 'hourly')
          assert_queue_item_rollup_chain(q_all[0], @host, 'hourly')
        end

        it "should queue up from Vm hourly to Host hourly and Vm daily" do
          @vm.perf_rollup_to_parent('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_item_rollup_chain(q_all[0], @host, 'hourly')
          assert_queue_item_rollup_chain(q_all[1], @vm,   'daily', @time_profile)
        end

        it "should queue up from Host hourly to EmsCluster hourly and Host daily" do
          @host.perf_rollup_to_parent('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_item_rollup_chain(q_all[0], @ems_cluster, 'hourly')
          assert_queue_item_rollup_chain(q_all[1], @host,        'daily', @time_profile)
        end

        it "should queue up from EmsCluster hourly to EMS hourly and EmsCluster daily" do
          @ems_cluster.perf_rollup_to_parent('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_item_rollup_chain(q_all[0], @ems_vmware,         'hourly')
          assert_queue_item_rollup_chain(q_all[1], @ems_cluster, 'daily', @time_profile)
        end

        it "should queue up from Vm daily to nothing" do
          @vm.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end

        it "should queue up from Host daily to nothing" do
          @host.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end

        it "should queue up from EmsCluster daily to nothing" do
          @ems_cluster.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end

        it "should queue up from EMS daily to nothing" do
          @ems_vmware.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end
      end
    end

    context ".day_to_range" do
      it "should return the correct start and end dates when calling day_to_range before DST starts" do
        s, e = Metric::Finders.day_to_range("2011-03-12T05:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
        s.should == '2011-03-12T05:00:00Z'
        e.should == '2011-03-13T04:59:59Z'
      end

      it "should return the correct start and end dates when calling day_to_range on the day DST starts" do
        s, e = Metric::Finders.day_to_range("2011-03-13T05:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
        s.should == '2011-03-13T05:00:00Z'
        e.should == '2011-03-14T03:59:59Z'
      end

      it "should return the correct start and end dates when calling day_to_range after DST starts" do
        s, e = Metric::Finders.day_to_range("2011-03-14T04:00:00Z", TimeProfile.new(:tz => "Eastern Time (US & Canada)"))
        s.should == '2011-03-14T04:00:00Z'
        e.should == '2011-03-15T03:59:59Z'
      end
    end

    context ".days_from_range" do
      it "should return the correct dates and times when calling days_from_range before DST starts" do
        days = Metric::Helper.days_from_range('2011-03-01T15:24:00Z', '2011-03-03T13:45:00Z', "Eastern Time (US & Canada)")
        days.should == ["2011-03-01T05:00:00Z", "2011-03-02T05:00:00Z", "2011-03-03T05:00:00Z"]
      end

      it "should return the correct dates and times when calling days_from_range when start and end dates span DST" do
        days = Metric::Helper.days_from_range('2011-03-12T11:23:00Z', '2011-03-14T14:33:00Z', "Eastern Time (US & Canada)")
        days.should == ["2011-03-12T05:00:00Z", "2011-03-13T05:00:00Z", "2011-03-14T04:00:00Z"]
      end

      it "should return the correct dates and times when calling days_from_range before DST starts" do
        days = Metric::Helper.days_from_range('2011-03-15T17:22:00Z', '2011-03-17T19:52:00Z', "Eastern Time (US & Canada)")
        days.should == ["2011-03-15T04:00:00Z", "2011-03-16T04:00:00Z", "2011-03-17T04:00:00Z"]
      end
    end

    context "Testing CPU % virtual cols with existing performance data" do
      it "should return the correct values for Vm realtime" do
        pdata = {
          :resource_type            => "VmOrTemplate",
          :capture_interval_name    => "realtime",
          :cpu_ready_delta_summation=> 1060.0,
          :cpu_used_delta_summation => 4012.0,
          :cpu_wait_delta_summation => 27090.0,
        }
        perf = Metric.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 5.3
        perf.v_pct_cpu_used_delta_summation.should  == 20.1
        perf.v_pct_cpu_wait_delta_summation.should  == 135.5
      end

      it "should return the correct values for Vm hourly" do
        pdata = {
          :resource_type            => "VmOrTemplate",
          :capture_interval_name    => "hourly",
          :intervals_in_rollup      => 180,
          :cpu_ready_delta_summation=> 10604.0,
          :cpu_used_delta_summation => 401296.0,
          :cpu_wait_delta_summation => 6709070.0,
        }
        perf = MetricRollup.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 0.3
        perf.v_pct_cpu_used_delta_summation.should  == 11.1
        perf.v_pct_cpu_wait_delta_summation.should  == 186.4
      end

      it "should return the correct values for Vm daily" do
        pdata = {
          :resource_type            => "VmOrTemplate",
          :capture_interval_name    => "daily",
          :intervals_in_rollup      => 24,
          :cpu_ready_delta_summation=> 10868.0833333333,
          :cpu_used_delta_summation => 131611.583333333,
          :cpu_wait_delta_summation => 6772579.45833333,
        }
        perf = MetricRollup.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 0.3
        perf.v_pct_cpu_used_delta_summation.should  == 3.7
        perf.v_pct_cpu_wait_delta_summation.should  == 188.1
      end

      it "should return the correct values for Host hourly" do
        pdata = {
          :resource_type            => "Host",
          :capture_interval_name    => "hourly",
          :intervals_in_rollup      => 179,
          :derived_vm_count_on      => 6,
          :cpu_ready_delta_summation=> 54281.0,
          :cpu_used_delta_summation => 2324833.0,
          :cpu_wait_delta_summation => 36722174.0,
        }
        perf = MetricRollup.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 0.3
        perf.v_pct_cpu_used_delta_summation.should  == 10.8
        perf.v_pct_cpu_wait_delta_summation.should  == 170.0

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0
      end

      it "should return the correct values for Host daily" do
        pdata = {
          :resource_type            => "Host",
          :capture_interval_name    => "daily",
          :intervals_in_rollup      => 24,
          :derived_vm_count_on      => 6,
          :cpu_ready_delta_summation=> 50579.1666666667,
          :cpu_used_delta_summation => 2180869.375,
          :cpu_wait_delta_summation => 36918805.4166667,
        }
        perf = MetricRollup.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 0.2
        perf.v_pct_cpu_used_delta_summation.should  == 10.1
        perf.v_pct_cpu_wait_delta_summation.should  == 170.9

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0
      end

      it "should return the correct values for Cluster hourly" do
        pdata = {
          :resource_type            => "EmsCluster",
          :capture_interval_name    => "hourly",
          :intervals_in_rollup      => nil,
          :derived_vm_count_on      => 10,
          :cpu_ready_delta_summation=> 58783.0,
          :cpu_used_delta_summation => 3668409.0,
          :cpu_wait_delta_summation => 60426340.0,
        }
        perf = MetricRollup.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 0.2
        perf.v_pct_cpu_used_delta_summation.should  == 10.2
        perf.v_pct_cpu_wait_delta_summation.should  == 167.9

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0
      end

      it "should return the correct values for Cluster daily" do
        pdata = {
          :resource_type            => "EmsCluster",
          :capture_interval_name    => "daily",
          :intervals_in_rollup      => 24,
          :derived_vm_count_on      => 10,
          :cpu_ready_delta_summation=> 54120.0833333333,
          :cpu_used_delta_summation => 3209660.54166667,
          :cpu_wait_delta_summation => 60868270.1666667,
        }
        perf = MetricRollup.new(pdata)

        perf.v_pct_cpu_ready_delta_summation.should == 0.2
        perf.v_pct_cpu_used_delta_summation.should  == 8.9
        perf.v_pct_cpu_wait_delta_summation.should  == 169.1

        pdata[:derived_vm_count_on] = nil
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0

        pdata[:derived_vm_count_on] = 0
        perf = MetricRollup.new(pdata)
        perf.v_pct_cpu_ready_delta_summation.should == 0
        perf.v_pct_cpu_used_delta_summation.should  == 0
        perf.v_pct_cpu_wait_delta_summation.should  == 0
      end
    end

    context "with a cluster" do
      context "maintains_value_for_duration?" do
        it "should handle the only event right before the starting on time (FB15770)" do
          @ems_cluster = FactoryGirl.create(:ems_cluster, :ext_management_system => @ems_vmware)
          @ems_cluster.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr,
                  :timestamp => Time.parse("2011-08-12T20:33:12Z")
          )

          options = {:debug_trace=>"false",
                     :value=>"50",
                     :operator=>">",
                     :duration=>3600,
                     :column=>"v_pct_cpu_ready_delta_summation",
                     :interval_name=>"hourly",
                     :starting_on => Time.parse("2011-08-12T20:33:20Z"),
                     :trend_direction=>"none"
          }
          @ems_cluster.performances_maintains_value_for_duration?(options).should == false
        end
      end
    end
  end

  context "as openstack" do
    before :each do
      @ems_openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
    end

    context "with enabled and disabled targets" do
      before(:each) do
        @availability_zone = FactoryGirl.create(:availability_zone_target)
        @ems_openstack.availability_zones << @availability_zone
        @vms_in_az = []
        2.times { @vms_in_az << FactoryGirl.create(:vm_openstack, :ems_id => @ems_openstack.id) }
        @availability_zone.vms = @vms_in_az

        @vms_not_in_az = []
        3.times { @vms_not_in_az << FactoryGirl.create(:vm_openstack, :ems_id => @ems_openstack.id) }

        MiqQueue.delete_all
      end

      context "executing capture_targets" do
        it "should find enabled targets" do
          targets = Metric::Targets.capture_targets
          assert_cloud_targets_enabled targets, %w{VmOpenstack VmOpenstack VmOpenstack VmOpenstack VmOpenstack}
        end

        it "should find no enabled targets excluding vms" do
          targets = Metric::Targets.capture_targets(nil, :exclude_vms => true)
          assert_cloud_targets_enabled targets, %w{}
        end
      end

      context "executing perf_capture_timer" do
        before(:each) do
          VMDB::Config.any_instance.stub(:config).and_return({:performance => {:history => {:initial_capture_days => 7}}})
          Metric::Capture.perf_capture_timer
        end

        it "should queue up enabled targets" do
          expected_targets = Metric::Targets.capture_targets
          expected_queue_count = expected_targets.size * 9  # 1 realtime, 8 historical
          expected_queue_count += 1                         # cleanup task
          MiqQueue.count.should == expected_queue_count

          expected = expected_targets.collect do |t|
            # Storage is hourly only
            # Non-storage historical is expecting 7 days back, plus partial day = 8
            t.is_a?(Storage) ? [t, "hourly"] : [[t, "realtime"], [t, "historical"] * 8]
          end.flatten

          selected = MiqQueue.all(:conditions => {:method_name => "perf_capture"}, :order => :id).collect do |q|
            [Object.const_get(q.class_name).find(q.instance_id), q.args.first]
          end.flatten

          selected.should == expected
        end
      end
    end

    context "with a vm" do
      before(:each) do
        @vm = FactoryGirl.create(:vm_perf_openstack, :ext_management_system => @ems_openstack)
      end

      context "queueing up realtime rollups to parent" do
        before(:each) do
          MiqQueue.delete_all
          @vm.perf_rollup_to_parent("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
        end

        it "should have queued rollups for vm hourly" do
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "VmOpenstack")
        end

        context "twice" do
          before(:each) do
            @vm.perf_rollup_to_parent("realtime", "2010-04-14T21:51:10Z", "2010-04-14T22:50:50Z")
          end

          it "should have one set of queued rollups" do
            q_all = MiqQueue.all(:order => :id)
            q_all.length.should == 2
            assert_queue_items_are_hourly_rollups(q_all, "2010-04-14T21:00:00Z", @vm.id, "VmOpenstack")
          end
        end
      end
    end

    context "with a full rollup chain and time profile" do
      before(:each) do
        @availability_zone = FactoryGirl.create(:availability_zone, :ext_management_system => @ems_openstack)
        @vm = FactoryGirl.create(:vm_openstack, :ext_management_system => @ems_openstack, :availability_zone => @availability_zone)

        @time_profile = FactoryGirl.create(:time_profile_utc)

        MiqQueue.delete_all
      end

      context "calling perf_rollup_to_parent" do
        it "should queue up from Vm realtime to Vm hourly" do
          @vm.perf_rollup_to_parent('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 1
          assert_queue_item_rollup_chain(q_all[0], @vm, 'hourly')
        end

        it "should queue up from AvailabilityZone realtime to AvailabilityZone hourly" do
          @availability_zone.perf_rollup_to_parent('realtime', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 1
          assert_queue_item_rollup_chain(q_all[0], @availability_zone, 'hourly')
        end

        it "should queue up from Vm hourly to AvailabilityZone hourly and Vm daily" do
          @vm.perf_rollup_to_parent('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_item_rollup_chain(q_all[0], @availability_zone, 'hourly')
          assert_queue_item_rollup_chain(q_all[1], @vm,   'daily', @time_profile)
        end

        it "should queue up from AvailabilityZone hourly to EMS hourly and AvailabilityZone daily" do
          @availability_zone.perf_rollup_to_parent('hourly', ROLLUP_CHAIN_TIMESTAMP)
          q_all = MiqQueue.all(:order => :id)
          q_all.length.should == 2
          assert_queue_item_rollup_chain(q_all[0], @ems_openstack,  'hourly')
          assert_queue_item_rollup_chain(q_all[1], @availability_zone, 'daily', @time_profile)
        end

        it "should queue up from Vm daily to nothing" do
          @vm.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end

        it "should queue up from AvailabilityZone daily to nothing" do
          @availability_zone.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end

        it "should queue up from EMS daily to nothing" do
          @ems_openstack.perf_rollup_to_parent('daily', ROLLUP_CHAIN_TIMESTAMP)
          MiqQueue.count.should == 0
        end
      end
    end
  end

  private

  def assert_queued_rollup(q_item, instance_id, class_name, args, deliver_on, method = "perf_rollup")
    deliver_on = Time.parse(deliver_on).utc if deliver_on.kind_of?(String)
    expected_deliver_on = q_item.deliver_on.utc.should unless deliver_on.nil?

    q_item.method_name.should    == method
    q_item.instance_id.should    == instance_id
    q_item.class_name.should     == class_name
    q_item.args.should           == args
    expected_deliver_on          == deliver_on
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

  def assert_infra_targets_enabled(targets, expected_types)
    # infra only
    selected_types = []
    targets.each do |t|
      selected_types << t.class.name

      expected_enabled = case t
      when Vm;      t.host.perf_capture_enabled?
      when Host;    t.perf_capture_enabled? || t.ems_cluster.perf_capture_enabled?
      when Storage; t.perf_capture_enabled?
      end
      expected_enabled.should be_true
    end

    selected_types.should match_array(expected_types)
  end

  def assert_cloud_targets_enabled(targets, expected_types)
    selected_types = []
    targets.each do |t|
      selected_types << t.class.name

      expected_enabled = case t
      # Vm's perf_capture_enabled is its availability_zone's perf_capture setting,
      #   or true if it has no availability_zone
      when Vm;                t.availability_zone ? t.availability_zone.perf_capture_enabled? : true
      when AvailabilityZone;  t.perf_capture_enabled?
      when Storage;           t.perf_capture_enabled?
      end
      expected_enabled.should be_true
    end

    selected_types.should =~ expected_types
  end

  def assert_perf_capture_now(target, mode)
    Timecop.freeze(Time.now) do
      target.update_attribute(:last_perf_capture_on, nil)
      target.perf_capture_now?.should be_true

      target.update_attribute(:last_perf_capture_on, Time.now.utc - 15.minutes)
      target.perf_capture_now?.should be_true

      target.update_attribute(:last_perf_capture_on, Time.now.utc - 7.minutes)
      (mode == :with_alerts ? target.perf_capture_now? : !target.perf_capture_now?).should be_true

      target.update_attribute(:last_perf_capture_on, Time.now.utc - 1.minutes)
      target.perf_capture_now?.should_not be_true
    end
  end

end
