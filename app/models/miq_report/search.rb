module MiqReport::Search
  extend ActiveSupport::Concern

  module ClassMethods
    def get_limit_offset(page, per_page)
      limit  = nil
      offset = nil
      unless per_page.nil?
        offset = (page - 1) * per_page
        limit  = per_page
      end
      return limit, offset
    end
  end

  def get_sqltable(assoc)
    r = db_class.reflection_with_virtual(assoc.to_sym)
    raise "Invalid reflection <#{assoc}> on model <#{db_class.name}>" if r.nil?
    r.klass.table_name
  end

  def get_cached_page(limit, offset, includes, options)
    ids          = extras[:target_ids_for_paging]
    if limit.kind_of?(Numeric)
      offset ||= 0
      ids      = ids[offset..offset + limit - 1]
    end
    data         = db_class.where(:id => ids).includes(includes).to_a
    targets_hash = data.index_by(&:id) if options[:targets_hash]
    build_table(data, db, options)
    return table, extras[:attrs_for_paging].merge(:paged_read_from_cache => true, :targets_hash => targets_hash)
  end

  def get_order_info
    order = nil
    apply_sortby_in_search = db_class.sortable?
    if apply_sortby_in_search && !sortby.nil?
      # Convert sort cols from sub-tables from the form of assoc_name.column to the form of table_name.column
      order = sortby.to_miq_a.collect do |c|
        col  = col_to_expression_col(c)
        info = MiqExpression.get_col_info(col)
        apply_sortby_in_search = false if info[:virtual_reflection] || info[:virtual_column]

        if c.include?(".")
          assoc, col = c.split(".")
          t = get_sqltable(assoc)
          sql_col = [t, col].join(".")
        else
          sql_col = [db_class.table_name, c].join(".")
        end
        sql_col = "LOWER(#{sql_col})" if [:string, :text].include?(info[:data_type])
        sql_col
      end.join(",")

      unless self.order.nil?
        case self.order.downcase
        when "ascending"  then order += " asc"
        when "descending" then order += " desc"
        end
      end
    end

    return apply_sortby_in_search, order
  end

  def get_parent_targets(parent, assoc)
    # Pre-build search target id list from association
    if parent.kind_of?(Hash)
      klass  = parent[:class].constantize
      id     = parent[:id]
      parent = klass.find(id)
    end
    assoc ||= db_class.base_model.to_s.pluralize.underscore  # Derive association from base model
    ref = parent.class.reflection_with_virtual(assoc.to_sym)
    if ref.nil? || parent.class.virtual_reflection?(assoc)
      targets = parent.send(assoc).collect(&:id) # assoc is either a virtual reflection or a method so just call the association and collect the ids
    else
      targets = parent.send(assoc).ids
    end
    targets
  end

  def paged_view_search(options = {})
    per_page = options.delete(:per_page)
    page     = options.delete(:page) || 1
    limit, offset = self.class.get_limit_offset(page, per_page)

    self.display_filter = options.delete(:display_filter_hash)  if options[:display_filter_hash]
    self.display_filter = options.delete(:display_filter_block) if options[:display_filter_block]

    includes = MiqExpression.merge_includes(get_include_for_find(include), include_for_find)

    self.extras ||= {}
    return get_cached_page(limit, offset, includes, options) if self.extras[:target_ids_for_paging] && db_class.column_names.include?('id')

    apply_sortby_in_search, order = get_order_info

    search_options = options.merge(:class => db, :conditions => conditions, :results_format => :objects, :include_for_find => includes)
    search_options.merge!(:limit => limit, :offset => offset, :order => order) if apply_sortby_in_search

    if options[:parent]
      targets = get_parent_targets(options[:parent], options[:association] || options[:parent_method])
      if targets.empty?
        search_results, attrs = [targets, {:auth_count => 0, :total_count => 0}]
      else
        search_results, attrs = Rbac.search(search_options.merge(:targets => targets))
      end
    else
      search_results, attrs = Rbac.search(search_options)
    end

    search_results ||= []

    unless apply_sortby_in_search
      options[:limit]   = limit
      options[:offset]  = offset
    else
      options[:no_sort] = true
      self.extras[:target_ids_for_paging] = attrs.delete(:target_ids_for_paging)
    end
    build_table(search_results, db, options)

    # build a hash of target objects for UI since we already have them
    if options[:targets_hash]
      attrs[:targets_hash] = {}
      search_results.each { |obj| attrs[:targets_hash][obj.id] = obj }
    end
    attrs[:apply_sortby_in_search] = apply_sortby_in_search
    self.extras[:attrs_for_paging] = attrs.merge(:targets_hash => nil) unless self.extras[:target_ids_for_paging].nil?

    _log.debug("Attrs: #{attrs.merge(:targets_hash => "...").inspect}")
    return table, attrs
  end
end
