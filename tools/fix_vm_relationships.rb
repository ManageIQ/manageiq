#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

### Used to fix VM to Parent Resource Pool relationship problems.
# Normally seen when user clicks on a VM to view VM summary page.
# Error is displayed "Couldn't find Relationship with id=XXXX [vm_or_template/tree_select]"

fixed_vms = []
rels_to_delete = []

Vm.includes(:all_relationships).each do |v|
  begin
    v.parent_resource_pool
  rescue ActiveRecord::RecordNotFound => err
    puts "FIXING - #{v.name} - #{err}"
    rels_to_delete += v.all_relationships.to_a.select { |r| r.relationship == "ems_metadata" }
    fixed_vms << v.reload
  else
    puts "OK     - #{v.name}"
  end
end
Relationship.delete(rels_to_delete)

if fixed_vms.empty?
  puts "No VM relationships to fix."
else
  puts "Fixed relationships for:"
  puts fixed_vms.collect(&:name)
  puts "Queueing refresh of relationships for VM's."
  EmsRefresh.queue_refresh(fixed_vms)
end
