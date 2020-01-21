#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

st = Time.now
@stop_message = "Provisioning stopped by external script."
@processed = []

def kill_provision_task(prov_id, queue)
  puts "Found Queue ID:#{queue.id} - #{queue.class_name}:#{queue.instance_id} - #{queue.method_name}"
  queue.destroy

  prov = MiqProvision.find_by(:id => prov_id)
  prov.update_and_notify_parent(:state => "finished", :status => "Error", :message => @stop_message)
  @processed << prov_id unless @processed.include?(prov_id)
end

args = $ARGV.join(',').gsub(',,', ',').split(',').uniq
provisions = args.collect { |a| a =~ /miq_provision_(\d*)/ ? $1.to_i : a.to_i }

puts "Checking for provisions IDs:<#{provisions.inspect}>"
provisions.each do |prov_id|
  MiqQueue.where(:method_name => 'do_post_provision', :class_name => 'MiqProvision', :instance_id => prov_id, :state => 'ready').each do |queue|
    kill_provision_task(prov_id, queue)
  end
  MiqQueue.where(:task_id => "miq_provision_#{prov_id}", :state => 'ready').each do |queue|
    kill_provision_task(prov_id, queue)
  end
end
puts "Successfully processed <#{@processed.length}> of <#{provisions.length}> in #{Time.now - st} seconds."
