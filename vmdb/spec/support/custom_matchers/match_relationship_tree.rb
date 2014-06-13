RSpec::Matchers.define :match_relationship_tree do |expected_tree|
  match do |actual_tree|
    actual_tree.length.should == expected_tree.length

    actual_tree   = sort_tree(actual_tree)
    expected_tree = sort_tree(expected_tree)

    actual_tree.each_with_index do |(obj, children), i|
      expected_array, expected_children = expected_tree[i]
      expected_type, expected_name, expected_options = expected_array

      obj.should      be_instance_of(expected_type)
      obj.name.should == expected_name
      expected_options.each { |k, v| obj.send(k).should == v } if expected_options

      children.should match_relationship_tree expected_children
    end
  end

  failure_message_for_should do |actual_tree|
    "expected actual tree\n#{pretty_tree(actual_tree)}\nto match expected tree\n#{pretty_tree(expected_tree)}"
  end

  failure_message_for_should_not do |actual_tree|
    "expected actual tree\n#{pretty_tree(actual_tree)}\nto not match expected tree\n#{pretty_tree(expected_tree)}"
  end

  description do
    "expect the object to have the same relationship tree"
  end

  def sort_tree(tree)
    return tree if tree.blank?

    if tree.first.first.kind_of?(Array)
      # sorting expected tree
      tree.sort_by { |key, children| [key[0].name,    key[1]] }
    else
      # sorting actual tree
      tree.sort_by { |obj, children| [obj.class.name, obj.name] }
    end
  end

  def pretty_tree(tree, indent = '  ')
    sort_tree(tree).each_with_object("") do |(obj, children), output|
      if obj.kind_of?(Array)
        # printing expected tree
        type, name, options = obj
        output << "#{indent}- #{type.name}: #{name}"
        output << " (#{options.inspect})" unless options.nil?
      else
        # printing actual tree
        output << "#{indent}- #{obj.class.name}: #{obj.name}"
      end

      output << "\n" << pretty_tree(children, "  #{indent}")
    end
  end
end
