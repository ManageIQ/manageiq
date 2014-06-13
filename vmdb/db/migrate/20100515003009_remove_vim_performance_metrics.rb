class RemoveVimPerformanceMetrics < ActiveRecord::Migration
  class MiqQueue < ActiveRecord::Base
    self.table_name = "miq_queue"
    serialize :args
  end

  class Vm < ActiveRecord::Base; end

  class Host < ActiveRecord::Base; end

  class VimPerformanceMetric < ActiveRecord::Base
    serialize :counter_values
    serialize :counters

    def self.counter_values_by_range(resource, start_time = nil, end_time = nil, interval = nil)
      start_time = start_time.utc.iso8601 unless start_time.nil? || start_time.kind_of?(String)
      end_time   = end_time.utc.iso8601   unless end_time.nil?   || end_time.kind_of?(String)

      metrics = find_all_by_range(resource, start_time, end_time, interval)
      return [] if metrics.empty?

      if metrics.length == 1
        counter_values = metrics[0].counter_values
        counters = metrics[0].counters
      else
        counter_values = {}
        counters = {}
        metrics.each do |m|
          counter_values.merge!(m.counter_values)
          counters.merge!(m.counters)
        end
      end

      # Find only the keys in the range specified
      keys = counter_values.keys.sort
      i1 = 0
      i1 += 1 until keys[i1] >= start_time unless start_time.nil?
      i2 = -1
      i2 -= 1 until keys[i2] <= end_time unless end_time.nil?
      keys = keys[i1..i2]

      # Return an array of timestamp, counter_values pairs
      vals = counter_values.values_at(*keys)
      return keys.zip(vals), counters
    end

    private

    def self.find_all_by_range(resource, start_time = nil, end_time = nil, interval = nil)
      cond = range_to_condition(start_time, end_time)
      unless interval.nil?
        cond[0] += " AND capture_interval_name = ?"
        cond << interval
      end

      cond[0] += " AND resource_type = ? AND resource_id = ?"
      cond << resource.class.name.split("::").last << resource.id

      return VimPerformanceMetric.where(cond).all
    end

    def self.range_to_condition(start_time, end_time)
      return nil if start_time.nil?

      cond = "end_timestamp >= ?"
      parms = [start_time]
      unless end_time.nil?
        cond << " AND start_timestamp <= ?"
        parms << end_time
      end
      parms.unshift(cond)
      return parms
    end
  end

  def self.up
    # Update any existing perf_process queue items with the data from
    #   vim_performance_metrics before we drop the table.
    say_with_time("Update MiqQueue perf_process records") do
      MiqQueue.where(:class_name => %w{Vm Host}, :method_name => "perf_process", :state => "ready").each do |q|
        next if q.args.nil? || q.args.length != 3

        resource = const_get(q.class_name).where(:id => q.instance_id).first
        next if resource.nil?

        counter_values, counters = VimPerformanceMetric.counter_values_by_range(resource, q.args[1], q.args[2], q.args[0])

        q.args << counters << counter_values
        q.role = 'performancecollector'
        q.queue_name = 'performancecollector'
        q.save!
      end
    end

    remove_index :vim_performance_metrics, [:resource_type, :resource_id]
    drop_table :vim_performance_metrics
  end

  def self.down
    create_table :vim_performance_metrics do |t|
      t.integer  :resource_id
      t.string   :resource_type
      t.text     :reserved
      t.text     :counter_values
      t.string   :capture_interval_name
      t.datetime :start_timestamp
      t.datetime :end_timestamp
      t.text     :counters
    end

    add_index :vim_performance_metrics, [:resource_type, :resource_id]
  end
end
