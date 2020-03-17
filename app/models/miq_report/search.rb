module MiqReport::Search
  extend ActiveSupport::Concern

  module ClassMethods
    def get_limit_offset(page, per_page)
      [per_page, (page - 1) * per_page] if per_page
    end
  end

  # @param assoc [String] associations and a column name
  # @raise if an association is not valid
  # @return nil if there is a virtual association in the path
  # @return [Class, String] ActiveRecord base object and column name for the association
  def association_column(assoc)
    parts = assoc.split(".")
    col = parts.pop
    klass = db_class.follow_associations_with_virtual(parts)
    raise _("Invalid reflection <%{item}> on model <%{name}>") % {:item => assoc, :name => db_class} if klass.nil?
    # only return attribute if it is accessible directly (not through virtual columns)
    [klass.arel_attribute(col), klass.type_for_attribute(col).type] if db_class.follow_associations(parts)
  end

  def limited_ids(limit, offset)
    ids = extras[:target_ids_for_paging]
    if limit.kind_of?(Numeric)
      offset ||= 0
      ids[offset...offset + limit]
    else
      ids
    end
  end

  def get_cached_page(ids, includes, options)
    data         = db_class.where(:id => ids).includes(includes).to_a
    targets_hash = data.index_by(&:id) if options[:targets_hash]
    build_table(data, db, options)
    return table, extras[:attrs_for_paging].merge(:paged_read_from_cache => true, :targets_hash => targets_hash)
  end

  # @return [Nil] for sorting in ruby
  # @return [Array<>] (empty array) for no sorting
  # @return [Array<Arel::Nodes>] for sorting in sql
  def get_order_info
    return [] if sortby.nil? # apply limits (note: without order it is non-deterministic)
    # Convert sort cols from sub-tables from the form of assoc_name.column to arel
    Array.wrap(sortby).collect do |c|
      sql_col, sql_type = association_column(c)
      return nil if sql_col.nil?
      sql_col = Arel::Nodes::NamedFunction.new('LOWER', [sql_col]) if [:string, :text].include?(sql_type)
      if order.nil?
        sql_col
      elsif ascending?
        Arel::Nodes::Ascending.new(sql_col)
      else
        Arel::Nodes::Descending.new(sql_col)
      end
    end
  end

  def get_parent_targets(parent, assoc)
    # Pre-build search target id list from association
    if parent.kind_of?(Hash)
      klass  = parent[:class].constantize
      id     = parent[:id]
      parent = klass.find(id)
    end
    assoc ||= db_class.base_model.to_s.pluralize.underscore # Derive association from base model
    ref   = parent.class.reflection_with_virtual(assoc.to_sym)
    if ref.nil? || parent.class.virtual_reflection?(assoc)
      parent.send(assoc).collect(&:id)
    else
      parent.send(assoc).ids
    end
  end

  def paged_view_search(options = {})
    per_page = options.delete(:per_page)
    page     = options.delete(:page) || 1
    selected_ids = options.delete(:selected_ids)
    limit, offset = self.class.get_limit_offset(page, per_page)

    self.display_filter = options.delete(:display_filter_hash)  if options[:display_filter_hash]
    self.display_filter = options.delete(:display_filter_block) if options[:display_filter_block]

    includes = get_include_for_find
    self.extras ||= {}
    if extras[:target_ids_for_paging] && db_class.column_names.include?('id')
      return get_cached_page(limited_ids(limit, offset), includes, options)
    end

    order = get_order_info

    search_options = options.merge(:class            => db,
                                   :conditions       => conditions,
                                   :include_for_find => includes,
                                   :references       => get_include
                                  )
    search_options.merge!(:limit => limit, :offset => offset, :order => order) if order
    search_options[:extra_cols] = va_sql_cols if va_sql_cols.present?
    search_options[:use_sql_view] = if db_options.nil? || db_options[:use_sql_view].nil?
                                      MiqReport.default_use_sql_view
                                    else
                                      db_options[:use_sql_view]
                                    end

    if options[:parent]
      targets = get_parent_targets(options[:parent], options[:association] || options[:parent_method])
    else
      targets = db_class
    end

    if selected_ids.present?
      targets = targets.first.kind_of?(Integer) ? targets & selected_ids : targets.where(:id => selected_ids)
    end

    supported_features_filter = search_options.delete(:supported_features_filter) if search_options[:supported_features_filter]
    search_results, attrs     = Rbac.search(search_options.merge(:targets => targets))
    filtered_results          = filter_results(search_results, supported_features_filter)

    if order.nil?
      options[:limit]   = limit
      options[:offset]  = offset
    else
      options[:no_sort] = true
      self.extras[:target_ids_for_paging] = attrs.delete(:target_ids_for_paging)
    end
    build_table(filtered_results, db, options)

    # build a hash of target objects for UI since we already have them
    if options[:targets_hash]
      attrs[:targets_hash] = {}
      filtered_results.each { |obj| attrs[:targets_hash][obj.id] = obj }
    end
    attrs[:apply_sortby_in_search] = !!order
    self.extras[:attrs_for_paging] = attrs.merge(:targets_hash => nil) unless self.extras[:target_ids_for_paging].nil?

    _log.debug("Attrs: #{attrs.merge(:targets_hash => "...").inspect}")
    return table, attrs
  end

  private

  def filter_results(results, supported_features_filter)
    return results if supported_features_filter.nil?
    results.select { |result| result.send(supported_features_filter) }
  end
end
