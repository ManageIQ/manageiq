module AncestryInstanceMethodsPatch
  def update_descendants_with_new_ancestry
    super
    unless ancestry_callbacks_disabled?
      clear_memoized_instance_variables
      if ancestry_changed? && !new_record? && sane_ancestry?
        unscoped_descendants.each(&:clear_memoized_instance_variables)
      end
    end
  end
end

module Ancestry
  module InstanceMethods
    prepend AncestryInstanceMethodsPatch

    def parse_ancestry_column(obj)
      obj.to_s.split('/').map! { |id| cast_primary_key(id) }
    end

    def ancestor_ids
      @_ancestor_ids ||= parse_ancestry_column(read_attribute(ancestry_base_class.ancestry_column))
    end

    STRING_BASED_KEYS = %i[string uuid text].freeze
    def cast_primary_key(key)
      if STRING_BASED_KEYS.include?(primary_key_type)
        key
      else
        key.to_i
      end
    end

    def clear_memoized_instance_variables
      @_ancestor_ids = nil
    end
  end
end
