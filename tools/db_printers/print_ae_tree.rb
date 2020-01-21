#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

# Rails.logger.level = $log.level = 0
def print_ae_tree(nodes, indent = "")
  nodes.sort_by { |n| n.name.downcase }.each do |node|
    title = node.class.name.demodulize[5..-1]
    puts "#{indent}#{title}: #{node.name}"
    [:ae_namespaces, :ae_classes, :ae_instances, :ae_methods].each do |meth|
      print_ae_tree(node.send(meth), "  #{indent}") if node.respond_to?(meth)
    end
  end
end

nodes = MiqAeNamespace.find_tree(:include => :ae_classes)
print_ae_tree(nodes)
