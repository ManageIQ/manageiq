module TreeKids
  extend ActiveSupport::Concern
  module ClassMethods
    def has_kids_for(klass, method_and_arguments)
      kids_generators[klass] = method_and_arguments
    end

    def kids_generators
      @kids_generators ||= superclass.try(:kids_generators).try(:dup) || {
        Hash => [:x_get_tree_custom_kids, :options],
      }
    end
  end

  # Get objects (or count) to [put into a tree under a parent node.
  # TODO: Perhaps push the object sorting down to SQL, if possible -- no point where there are few items.
  # parent  --- Parent object for which we need child tree nodes returned
  # options --- Options:
  #   :count_only           # Return only the count if true -- remove this
  #   :leaf                 # Model name of leaf nodes, i.e. "Vm"
  #   :open_all             # if true open all node (no autoload)
  #   :load_children
  # parents --- an Array of parent object ids, starting from tree root + 1, ending with parent's parent; only available when full_ids and not lazy
  def x_get_tree_kids(parent, count_only, options, parents)
    generator = self.class.kids_generators.detect { |k, v| v if parent.kind_of? k }
    return nil unless generator
    method = generator[1][0]
    attributes = generator[1][1..-1].collect do |attribute_name|
      case attribute_name
      when :options then options
      when :type then options[:type]
      when :parents then parents
      end
    end
    send(method, *([parent, count_only] + attributes))
  end
end
