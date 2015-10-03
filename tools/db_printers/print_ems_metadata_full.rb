def print_subtree(subtree, indent = '')
  subtree = subtree.sort_by { |obj, _children| [obj.class.name, obj.name.downcase] }
  subtree.each do |obj, children|
    case obj
    when EmsCluster then obj.hosts.each { |h| children[h] = {} }
    when Host then       obj.vms_and_templates.each { |v| children[v] = {} }
    end

    sub_type = case obj
               when EmsFolder    then obj.is_datacenter ? "  (datacenter)" : ""
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
  puts; puts
end
