module ArReferences
  # Tags bring back too many rows, since we can not limit on the particular tag
  # So dont require them (meaning we don't join to the taggings table)
  SKIP_TABLES = [:tags, :taggings].freeze

  # Given a nested hash of associations (used by includes)
  #   convert into an array of table names (used by references)
  # If given an array of table names, will output the same array
  def includes_to_references(inc)
    return [] unless inc

    inc = Array(inc) unless inc.kind_of?(Hash)
    inc.flat_map do |n, v|
      if (ref = reflect_on_association(n.to_sym))
        n_table = ref.table_name unless ref.polymorphic?
        # ignore polymorphic references and tags
        if n_table.nil? || SKIP_TABLES.include?(n_table.to_sym)
          []
        else
          v_tables = v ? ref.klass.try(:includes_to_references, v) : []
          [n_table] + v_tables
        end
      elsif reflection_with_virtual(n.to_sym) || virtual_attribute?(n.to_sym) # ignore virtual collections and virtual attribute
        []
      else # it is probably a table name - keep it
        n
      end
    end
  end

  def prune_references(inc)
    return {} unless inc

    inc = Array(inc) unless inc.kind_of?(Hash) || inc.kind_of?(Array)
    inc.each_with_object(inc.class.new) do |(n, v), ret|
      n = n.to_sym
      if (ref = reflect_on_association(n))
        if !ref.polymorphic? && !SKIP_TABLES.include?(n)
          v_tables = ref.klass.try(:prune_references, v)
          if ret.kind_of?(Hash)
            byebug if v_tables.nil?
            ret[n] = v_tables || {}
          else
            byebug unless v.blank?
            ret << n
          end
        end
      # ignore virtual collections and virtual attribute
      elsif !reflection_with_virtual(n) && !virtual_attribute?(n)
        # Think this is an error. letting it slide (assuming it will throw an error elsewhere)
        ret[n] = {}
      end
    end
  end
end
