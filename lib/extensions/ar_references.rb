module ArReferences
  # Tags bring back too many rows, since we can not limit on the particular tag
  # So dont require them (meaning we don't join to the taggings table)
  SKIP_TABLES = [:tags, :taggings].freeze

  # Given a nested hash of associations (used by includes, preload, and eager_load)
  #   prune out polymorphic, and references to tags
  def prune_references(inc)
    return {} unless inc

    inc = Array(inc) unless inc.kind_of?(Hash) || inc.kind_of?(Array)
    inc.each_with_object({}) do |(n, v), ret|
      n = n.to_sym
      if (ref = reflect_on_association(n))
        if !ref.polymorphic? && !SKIP_TABLES.include?(n)
          ret[n] = (v.present? && ref.klass.try(:prune_references, v)) || {}
        end
      # ignore virtual collections and virtual attribute
      elsif !reflection_with_virtual(n) && !virtual_attribute?(n)
        # Think this is an error. letting it slide (assuming it will throw an error elsewhere)
        ret[n] = {}
      end
    end
  end
end
