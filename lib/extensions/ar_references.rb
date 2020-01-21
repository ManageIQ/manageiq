module ArReferences
  # Given a nested hash of associations (used by includes)
  #   convert into an array of table names (used by references)
  # If given an array of table names, will output the same array
  def includes_to_references(inc)
    return [] unless inc

    inc = Array(inc) unless inc.kind_of?(Hash)
    inc.flat_map do |n, v|
      if (ref = reflect_on_association(n.to_sym)) && !ref.polymorphic?
        n_table = ref.table_name
        v_tables = v ? ref.klass.try(:includes_to_references, v) : []
        [n_table] + v_tables
      elsif reflection_with_virtual(n.to_sym) # ignore polymorphic and virtual attribute
        []
      else # it is probably a table name - keep it
        n
      end
    end
  end
end
