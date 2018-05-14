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

    ANCESTRY_DELIMITER = '/'.freeze

    def parse_ancestry_column(obj)
      obj.to_s.split(ANCESTRY_DELIMITER).map! { |id| cast_primary_key(id) }
    end

    def ancestor_ids
      @_ancestor_ids ||= parse_ancestry_column(read_attribute(ancestry_base_class.ancestry_column))
    end

    def depth
      @_depth ||= if @_ancestor_ids
                    @_ancestor_ids.size
                  else
                    col = read_attribute(ancestry_base_class.ancestry_column)
                    col ? col.count(ANCESTRY_DELIMITER) + 1 : 0
                  end
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
      @_depth        = nil
    end
  end
end
