require "spec_helper"
require Rails.root.join("db/migrate/20100515003009_remove_vim_performance_metrics.rb")

describe RemoveVimPerformanceMetrics do
  migration_context :up do
    let(:queue_stub)  { migration_stub(:MiqQueue) }
    let(:metric_stub) { migration_stub(:VimPerformanceMetric) }
    let(:vm_stub)     { migration_stub(:Vm) }
    let(:host_stub)   { migration_stub(:Host) }

    shared_examples "updates ready perf_process MiqQueue records" do
      context "updates ready perf_process MiqQueue records" do
        it "with metrics in the time range" do
          q  = queue_stub.create!(:method_name => "perf_process", :state => "ready", :class_name => record_class, :instance_id => record.id, :args => ["realtime", 5.minutes.ago.utc, Time.now.utc])
          orig_args = q.args

          start_ts               = orig_args.last - 2.minutes
          end_ts                 = start_ts + 20.seconds
          metric1_counters       = {:counter1 => "abc"}
          metric1_counter_values = {start_ts.iso8601 => {:counter1 => 123}, end_ts.iso8601 => {:counter1 => 234}}
          metric1                = metric_stub.create!(:capture_interval_name => "realtime", :resource_type => record_class, :resource_id => record.id, :start_timestamp => start_ts, :end_timestamp => end_ts, :counters => metric1_counters, :counter_values => metric1_counter_values)

          start_ts2              = end_ts + 20.seconds
          end_ts2                = start_ts2 + 20.seconds
          metric2_counters       = {:counter2 => "def"}
          metric2_counter_values = {start_ts2.iso8601 => {:counter2 => 345}, end_ts2.iso8601 => {:counter2 => 456}}
          metric2                = metric_stub.create!(:capture_interval_name => "realtime", :resource_type => record_class, :resource_id => record.id, :start_timestamp => start_ts, :end_timestamp => end_ts, :counters => metric2_counters, :counter_values => metric2_counter_values)

          migrate

          q.reload.should have_attributes(
            :args       => [*orig_args, metric1_counters.merge(metric2_counters), metric1_counter_values.to_a + metric2_counter_values.to_a],
            :role       => 'performancecollector',
            :queue_name => 'performancecollector'
          )
        end

        it "with no metrics in time range" do
          q  = queue_stub.create!(:method_name => "perf_process", :state => "ready", :class_name => record_class, :instance_id => record.id, :args => ["realtime", 5.minutes.ago.utc, Time.now.utc])
          orig_args = q.args

          migrate

          q.reload.should have_attributes(
            :args       => [*orig_args, nil, nil],
            :role       => 'performancecollector',
            :queue_name => 'performancecollector'
          )
        end
      end
    end

    context "for Vms" do
      let(:record)       { vm_stub.create! }
      let(:record_class) { vm_stub.name.split("::").last }
      include_examples "updates ready perf_process MiqQueue records"
    end

    context "for Hosts" do
      let(:record)       { host_stub.create! }
      let(:record_class) { host_stub.name.split("::").last }
      include_examples "updates ready perf_process MiqQueue records"
    end

    context "ignores" do
      it "ready perf_process MiqQueue records where the resource no longer exists" do
        q = queue_stub.create!(:method_name => "perf_process", :state => "ready", :class_name => "Vm", :instance_id => 1, :args => ["realtime", 5.minutes.ago.utc, Time.now.utc])
        orig_attributes = q.attributes

        migrate

        q.reload.should have_attributes orig_attributes
      end

      it "dequeued perf_process MiqQueue records" do
        q = queue_stub.create!(:method_name => "perf_process", :state => "dequeue", :class_name => "Vm", :instance_id => 1, :args => ["realtime", 5.minutes.ago.utc, Time.now.utc])
        orig_attributes = q.attributes

        migrate

        q.reload.should have_attributes orig_attributes
      end

      it "non perf_process MiqQueue records" do
        q = queue_stub.create!(:method_name => "start", :state => "ready", :class_name => "Vm", :instance_id => 1, :args => [])
        orig_attributes = q.attributes

        migrate

        q.reload.should have_attributes orig_attributes
      end
    end
  end
end
