#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

def print_subtree(subtree, indent = '')
  subtree = subtree.sort_by { |obj, _children| [obj.class.name, obj.name.downcase] }
  subtree.each do |obj, children|
    sub_type = case obj
               when Datacenter   then "  (datacenter)"
               when EmsFolder    then ""
               when ResourcePool then obj.is_default ? "  (default)" : ""
               else ""
               end
    puts "#{indent}- #{obj.class}: #{obj.name}#{sub_type}"
    print_subtree(children, "  #{indent}")
  end
end

ExtManagementSystem.all.each do |ems|
  puts "EMS: #{ems.name}  (id: #{ems.id})"
  print_subtree(ems.descendants_arranged)
  puts("\n")
end
