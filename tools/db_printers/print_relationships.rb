#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

def print_rels(subtree, indent = '')
  subtree = subtree.sort_by { |rel, _children| rel.resource_pair }
  subtree.each do |rel, children|
    puts "#{indent}- #{rel.resource_type} #{rel.resource_id} (#{rel.id})"
    print_rels(children, "  #{indent}")
  end
end

roots = Relationship.roots.sort_by(&:resource_pair)
roots.each do |root|
  print_rels(root.subtree.arrange)
  puts("\n")
end
