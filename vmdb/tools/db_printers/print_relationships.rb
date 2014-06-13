def print_rels(subtree, indent = '')
  subtree = subtree.sort_by { |rel, children| rel.resource_pair }
  subtree.each do |rel, children|
    puts "#{indent}- #{rel.resource_type} #{rel.resource_id} (#{rel.id})"
    print_rels(children, "  #{indent}")
  end
end

roots = Relationship.roots.sort_by { |rel| rel.resource_pair }
roots.each do |root|
  print_rels(root.subtree.arrange)
  puts; puts
end
