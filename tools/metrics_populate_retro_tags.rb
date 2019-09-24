#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

# Rails.logger.level = 0

start_ts, end_ts, id_spec = ARGV

klass, ids = id_spec.split(":")
klass = klass.classify.constantize
ids = ids.split(",").compact
if klass == Vm
  vm_ids = ids
else
  vm_ids = []
  meth = klass.instance_methods.collect(&:to_s).include?("all_vms") ? :all_vms : :vms
  klass.where(:id => ids).each do |obj|
    vm_ids += obj.send(meth).collect(&:id)
  end
end
vm_ids.uniq!

time_cond = {:timestamp => (start_ts.to_time.utc.beginning_of_day..end_ts.to_time.utc.end_of_day)}
puts "Processing VM IDs: #{vm_ids.sort.inspect} for time range: #{time_cond.inspect}"

vm_perf_recs = MetricRollup.where(time_cond).where(:capture_interval_name => 'hourly', :resource_id => vm_ids)
               .includes(:vm => {:taggings => :tag})
               .select(:id, :resource_type, :resource_id, :resource_name, :parent_host_id)

vm_perf_recs.group_by(&:resource_id).sort.each do |resource_id, perfs|
  puts "Updating tags in performance data for VM: ID: #{resource_id} => #{perfs.first.resource_name}"
  MetricRollup.update_all(
    {:tag_names => perfs.first.vm.perf_tags},
    :id        => perfs.collect(&:id)
  )
end
