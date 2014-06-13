# Rails.logger.level = 0

start_ts, end_ts, id_spec = ARGV

klass, ids = id_spec.split(":")
klass = klass.classify.constantize
ids = ids.split(",").compact
if klass == Vm
  vm_ids = ids
else
  vm_ids = []
  meth = klass.instance_methods.collect { |m| m.to_s }.include?("all_vms") ? :all_vms : :vms
  klass.find_all_by_id(ids).each do |obj|
    vm_ids += obj.send(meth).collect {|v| v.id}
  end
end
vm_ids.uniq!

time_cond = {:timestamp => (start_ts.to_time.utc.beginning_of_day..end_ts.to_time.utc.end_of_day)}
puts "Processing VM IDs: #{vm_ids.sort.inspect} for time range: #{time_cond.inspect}"

vm_perf_recs = MetricRollup.all(
  :conditions => time_cond.merge(:capture_interval_name=>'hourly', :resource_id=>vm_ids),
  :include => {:vm=>{:taggings=>:tag}},
  :select => "id, resource_type, resource_id, resource_name, parent_host_id"
)

vm_perf_recs.group_by {|p| p.resource_id}.sort.each do |resource_id,perfs|
  puts "Updating tags in performance data for VM: ID: #{resource_id} => #{perfs.first.resource_name}"
  MetricRollup.update_all(
    {:tag_names => VimPerformanceState.capture_tag_names(perfs.first.vm)},
    {:id        => perfs.collect {|p| p.id}}
  )
end

host_ids = vm_perf_recs.collect {|p| p.parent_host_id}.compact.uniq
Host.find_all_by_id(host_ids, :order => :id).each do |host|
  puts "Updating performance breakdown by tags for VMs under Host: ID: #{host.id} => #{host.name}"

  host.preload_vim_performance_state_for_ts(time_cond)
  perf_recs = host.metric_rollups.all(:conditions => time_cond.merge(:capture_interval_name=>'hourly'))
  VimPerformanceTagValue.delete_all(:metric_type => "Host", :metric_id => perf_recs.collect {|p| p.id})
  perf_recs.each do |perf|
    perf.resource.target = host
    VimPerformanceTagValue.build_from_performance_record(perf)
  end
end
