RSpec::Matchers.define :match_relationship_tree do |expected_tree|
  match do |actual_tree|
    expect(actual_tree.length).to eq(expected_tree.length)

    actual_tree   = sort_tree(actual_tree)
    expected_tree = sort_tree(expected_tree)

    actual_tree.each_with_index do |(obj, children), i|
      expected_array, expected_children = expected_tree[i]
      expected_type, expected_name, expected_options = expected_array

      expect(obj).to be_instance_of(expected_type)
      expect(obj.name).to eq(expected_name)
      expected_options.each { |k, v| expect(obj.send(k)).to eq(v) } if expected_options

      expect(children).to match_relationship_tree expected_children
    end
  end

  failure_message do |actual_tree|
    "expected actual tree\n#{pretty_tree(actual_tree)}\nto match expected tree\n#{pretty_tree(expected_tree)}"
  end

  failure_message_when_negated do |actual_tree|
    "expected actual tree\n#{pretty_tree(actual_tree)}\nto not match expected tree\n#{pretty_tree(expected_tree)}"
  end

  description do
    "expect the object to have the same relationship tree"
  end

  def sort_tree(tree)
    return tree if tree.blank?

    if tree.first.first.kind_of?(Array)
      # sorting expected tree
      tree.sort_by { |key, _children| [key[0].name,    key[1]] }
    else
      # sorting actual tree
      tree.sort_by { |obj, _children| [obj.class.name, obj.name] }
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
