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
    r = self.db_class.reflect_on_association(assoc.to_sym)
    raise "Invalid reflection <#{assoc}> on model <#{self.db_class.name}>" if r.nil?
    r.klass.table_name
  end

  def get_cached_page(limit, offset, includes, options)
    ids          = self.extras[:target_ids_for_paging]
    if limit.kind_of?(Numeric)
      offset ||= 0
      ids      = ids[offset..offset + limit - 1]
    end
    data         = self.db_class.find_all_by_id(ids, :include => includes)
    targets_hash = data.index_by(&:id) if options[:targets_hash]
    self.build_table(data, self.db, options)
    return self.table, self.extras[:attrs_for_paging].merge(:paged_read_from_cache => true, :targets_hash => targets_hash)
  end

  def get_order_info
    order = nil
    apply_sortby_in_search = db_class.sortable?
    if apply_sortby_in_search && !self.sortby.nil?
      # Convert sort cols from sub-tables from the form of assoc_name.column to the form of table_name.column
      order = self.sortby.to_miq_a.collect do |c|
        col  = self.col_to_expression_col(c)
        info = MiqExpression.get_col_info(col)
        apply_sortby_in_search = false if info[:virtual_reflection] ||  info[:virtual_column]

        if c.include?(".")
          assoc, col = c.split(".")
          t = self.get_sqltable(assoc)
          sql_col = [t, col].join(".")
        else
          sql_col = [self.db_class.table_name, c].join(".")
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

  def get_parent_targets(options)
    options = options.dup

   # Pre-build search target id list from association
    parent = options.delete(:parent)
    if parent.kind_of?(Hash)
      klass  = parent[:class].constantize
      id     = parent[:id]
      parent = klass.find(id)
    end
    assoc = options.delete(:association) || options.delete(:parent_method)
    assoc ||= self.db_class.base_model.to_s.pluralize.underscore  # Derive association from base model
    ref = parent.class.reflection_with_virtual(assoc.to_sym)
    if ref.nil? || ref.kind_of?(VirtualReflection)
      targets = parent.send(assoc).collect(&:id) # assoc is either a virtual reflection or a method so just call the association and collect the ids
    else
      #TODO: Can we use the pre-built _ids methods that come with Rails?
      targets = parent.send(assoc).send(:find, :all, :select => 'id').collect(&:id)
    end
    return targets
  end

  def paged_view_search(options = {})
    per_page = options.delete(:per_page)
    page     = options.delete(:page) || 1
    limit, offset = self.class.get_limit_offset(page, per_page)

    self.display_filter = options.delete(:display_filter_hash)  if options[:display_filter_hash]
    self.display_filter = options.delete(:display_filter_block) if options[:display_filter_block]

    includes = MiqExpression.merge_includes(self.get_include_for_find(self.include), self.include_for_find)

    self.extras ||= {}
    return get_cached_page(limit, offset, includes, options) if self.extras[:target_ids_for_paging]

    apply_sortby_in_search, order = get_order_info

    search_options = options.merge(:class => self.db, :conditions => self.conditions, :results_format => :objects, :include_for_find => includes)
    search_options.merge!(:limit => limit, :offset => offset, :order => order) if apply_sortby_in_search

    unless options[:parent]
      search_results, attrs = Rbac.search(search_options)
    else
      targets = get_parent_targets(options)
      search_results, attrs = targets.empty? ? [targets, {:auth_count => 0, :total_count => 0}] : Rbac.search(search_options.merge(:targets => targets))
    end

    search_results ||= []

    unless apply_sortby_in_search
      options[:limit]   = limit
      options[:offset]  = offset
    else
      options[:no_sort] = true
      self.extras[:target_ids_for_paging] = attrs.delete(:target_ids_for_paging)
    end
    build_table(search_results, self.db, options)

    # build a hash of target objects for UI since we already have them
    if options[:targets_hash]
      attrs[:targets_hash] = {}
      search_results.each { |obj| attrs[:targets_hash][obj.id] = obj }
    end
    attrs[:apply_sortby_in_search] = apply_sortby_in_search
    self.extras[:attrs_for_paging] = attrs.merge(:targets_hash => nil) unless self.extras[:target_ids_for_paging].nil?

    $log.debug("MIQ(MiqReport#paged_view_search): Attrs: #{attrs.merge(:targets_hash => "...").inspect}")
    return self.table, attrs
  end
end
