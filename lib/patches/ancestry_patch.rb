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

  def parent=(parent)
    super
    clear_memoized_instance_variables
  end

  def parent_id=(parent)
    super
    clear_memoized_instance_variables
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

    def parent_id
      return @_parent_id if defined?(@_parent_id)
      @_parent_id = if @_ancestor_ids
                      @_ancestor_ids.empty? ? nil : @_ancestor_ids.last
                    else
                      col = read_attribute(ancestry_base_class.ancestry_column)
                      # Specifically not using `.blank?` here because it is
                      # slower than doing the below.
                      if col.nil? || col.empty? # rubocop:disable Rails/Blank
                        nil
                      else
                        rindex = col.rindex(ANCESTRY_DELIMITER)
                        cast_primary_key(rindex ? col[rindex + 1, col.length] : col)
                      end
                    end
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

      # can't assign to `nil` since `nil` could be a valid result
      remove_instance_variable(:@_parent_id) if defined?(@_parent_id)
    end
  end
end
