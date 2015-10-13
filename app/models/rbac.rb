module Rbac
  # This list is used to detemine whether RBAC, based on assigned tags, should be applied for a class in a search that is based on the class.
  # Classes should be added to this list ONLY after:
  # 1. It has been added to the MiqExpression.@@base_tables list
  # 2. Tagging has been enabled in the UI
  # 3. Class contains acts_as_miq_taggable
  CLASSES_THAT_PARTICIPATE_IN_RBAC = %w(
    AvailabilityZone
    CloudTenant
    ConfiguredSystem
    Container
    ContainerGroup
    ContainerNode
    EmsCluster
    EmsFolder
    ExtManagementSystem
    Flavor
    Host
    MiqCimInstance
    OrchestrationTemplate
    Repository
    ResourcePool
    SecurityGroup
    Service
    ServiceTemplate
    Storage
    VmOrTemplate
  )

  TAGGABLE_FILTER_CLASSES = CLASSES_THAT_PARTICIPATE_IN_RBAC - %w(EmsFolder)

  BELONGSTO_FILTER_CLASSES = %w(
    VmOrTemplate
    Host
    ExtManagementSystem
    EmsFolder
    EmsCluster
    ResourcePool
    Storage
  )

  MATCH_VIA_DESCENDANT_RELATIONSHIPS = {
    "VmOrTemplate::ExtManagementSystem" => :ext_management_system,
    "VmOrTemplate::Host"                => :host,
    "VmOrTemplate::EmsCluster"          => :ems_cluster,
    "VmOrTemplate::EmsFolder"           => :parent_blue_folders,
    "VmOrTemplate::ResourcePool"        => :resource_pool,
  }

  # These classes should accept any of the relationship_mixin methods including:
  #   :parent_ids
  #   :ancestor_ids
  #   :child_ids
  #   :sibling_ids
  #   :descendant_ids
  #   ...
  TENANT_ACCESS_STRATEGY = {
    'ExtManagementSystem'    => :ancestor_ids,
    'MiqAeNamespace'         => :ancestor_ids,
    'MiqRequest'             => nil, # tenant only
    'MiqRequestTask'         => nil, # tenant only
    'Provider'               => :ancestor_ids,
    'ServiceTemplateCatalog' => :ancestor_ids,
    'ServiceTemplate'        => :ancestor_ids,
    'Service'                => :descendant_ids,
    'Vm'                     => :descendant_ids
  }

  NO_SCOPE = :_no_scope_

  ########################################################################################
  # RBAC is:
  #   Self-Service CIs OR (ManagedFilters CIs AND BelongsToFilters CIs)
  #     ManagedFilters   is: ManagedFilters.any?   { |f| matched_filter(f) }
  #     BelongsToFilters is: BelongsToFilters.any? { |f| matched_filter(f) }
  ########################################################################################

  def self.apply_user_group_rbac_to_class?(klass)
    [User, MiqGroup].include?(klass)
  end

  def self.safe_base_class(klass)
    klass = klass.base_class if klass.respond_to?(:base_class)
    klass
  end

  def self.apply_rbac_to_class?(klass)
    CLASSES_THAT_PARTICIPATE_IN_RBAC.include?(safe_base_class(klass).name)
  end

  def self.apply_rbac_to_associated_class?(klass)
    return false if klass == Metric
    return false if klass == MetricRollup
    return false if klass == VimPerformanceDaily
    klass < MetricRollup || klass < Metric
  end

  def self.rbac_class(klass)
    return klass if apply_rbac_to_class?(klass)
    if apply_rbac_to_associated_class?(klass)
      return klass.name[0..-12].constantize.base_class # e.g. VmPerformance => VmOrTemplate
    end
    nil
  end

  def self.rbac_instance(obj)
    return obj                if apply_rbac_to_class?(obj.class)
    return obj.resource       if obj.kind_of?(MetricRollup) || obj.kind_of?(Metric)
    nil
  end

  def self.get_self_service_objects(user_or_group, klass)
    return nil unless user_or_group && user_or_group.self_service?
    return nil unless klass.ancestors.include?(OwnershipMixin)

    # Get the list of objects that are owned by the user or their LDAP group
    cond = user_or_group.limited_self_service? ? klass.conditions_for_owned(user_or_group) : klass.conditions_for_owned_or_group_owned(user_or_group)
    klass.select(minimum_columns_for(klass)).where(cond)
  end

  def self.get_self_service_object_ids(user_or_group, klass)
    targets = get_self_service_objects(user_or_group, klass)
    targets = targets.collect(&:id) if targets.respond_to?(:collect)
    targets
  end

  #
  # Algorithm: filter = u_filtered_ids UNION (b_filtered_ids INTERSECTION m_filtered_ids)
  #            filter = filter UNION d_filtered_ids if filter is not nil
  #  Each of the x_filtered_ids can be nil, which means that it does not apply
  # Output can be nil (filters do not apply) or an array of ids
  def self.combine_filtered_ids(u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
    filtered_ids =
      if b_filtered_ids.nil?
        m_filtered_ids
      elsif m_filtered_ids.nil?
        b_filtered_ids
      else
        b_filtered_ids & m_filtered_ids
      end

    if u_filtered_ids.kind_of?(Array)
      filtered_ids ||= []
      filtered_ids += u_filtered_ids
    end

    if filtered_ids.kind_of?(Array)
      filtered_ids += d_filtered_ids if d_filtered_ids.kind_of?(Array)
      filtered_ids.uniq!
    end

    filtered_ids
  end

  def self.find_targets_with_indirect_rbac(klass, scope, rbac_filters, find_options = {}, user_or_group = nil)
    parent_class   = rbac_class(klass)
    u_filtered_ids = get_self_service_object_ids(user_or_group, parent_class)
    b_filtered_ids = get_belongsto_filter_object_ids(parent_class, rbac_filters['belongsto'])
    m_filtered_ids = get_managed_filter_object_ids(parent_class, parent_class, rbac_filters['managed'])
    d_filtered_ids = rbac_filters['ids_via_descendants']
    filtered_ids   = combine_filtered_ids(u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)

    find_targets_filtered_by_parent_ids(parent_class, klass, scope, find_options, filtered_ids)
  end

  def self.compute_total_count(klass, scope, extra_target_ids, conditions, includes = nil)
    cond_for_count =
      if extra_target_ids.nil?
        conditions
      else
        # sanitize_sql_for_conditions is deprecated (at least when given
        # a hash).. but we can ignore it for now. When it goes away,
        # we'll be on Rails 5.0, and can use Relation#or instead.
        ActiveSupport::Deprecation.silence do
          ids_clause = klass.send(:sanitize_sql_for_conditions, :id => extra_target_ids)
          if conditions.nil?
            ids_clause
          else
            original_conditions = klass.send(:sanitize_sql_for_conditions, conditions)
            "(#{original_conditions}) OR (#{ids_clause})"
          end
        end
      end
    scope.where(cond_for_count).includes(includes).references(includes).count
  end

  def self.find_reflection(klass, association_to_match)
    klass.reflections.each do |association, reflection|
      next unless association == association_to_match
      return reflection
    end
    nil
  end

  def self.find_targets_filtered_by_parent_ids(parent_class, klass, scope, find_options, filtered_ids)
    total_count = scope.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count
    if filtered_ids.kind_of?(Array)
      reflection = find_reflection(klass, parent_class.name.underscore.to_sym)
      if reflection
        ids_clause = ["#{klass.table_name}.#{reflection.foreign_key} IN (?)", filtered_ids]
      else
        ids_clause = ["#{klass.table_name}.resource_type = ? AND #{klass.table_name}.resource_id IN (?)", parent_class.name, filtered_ids]
      end

      find_options[:conditions] = MiqExpression.merge_where_clauses(find_options[:conditions], ids_clause)
      _log.debug("New Find options: #{find_options.inspect}")
    end
    targets     = method_with_scope(scope, find_options)
    auth_count  = scope.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count

    return targets, total_count, auth_count
  end

  def self.find_targets_filtered_by_ids(klass, scope, find_options, u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
    total_count  = compute_total_count(klass, scope, u_filtered_ids, find_options[:conditions], find_options[:include])
    filtered_ids = combine_filtered_ids(u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
    if filtered_ids.kind_of?(Array)
      ids_clause  = ["#{klass.table_name}.id IN (?)", filtered_ids]
      find_options[:conditions] = MiqExpression.merge_where_clauses(find_options[:conditions], ids_clause)
      _log.debug("New Find options: #{find_options.inspect}")
    end
    targets     = method_with_scope(scope, find_options)
    auth_count  = klass.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count

    return targets, total_count, auth_count
  end

  def self.get_belongsto_filter_object_ids(klass, filter)
    return nil if filter.nil? || filter.empty?
    return nil unless BELONGSTO_FILTER_CLASSES.include?(safe_base_class(klass).name)
    get_belongsto_matches(filter, rbac_class(klass)).collect(&:id)
  end

  def self.get_managed_filter_object_ids(klass, scope, filter)
    return nil if filter.nil? || filter.empty?
    return nil unless TAGGABLE_FILTER_CLASSES.include?(safe_base_class(klass).name)
    scope.find_tags_by_grouping(filter, :ns => '*', :select => minimum_columns_for(klass)).collect(&:id)
  end

  def self.find_targets_with_direct_rbac(klass, scope, rbac_filters, find_options = {}, user_or_group = nil)
    u_filtered_ids = get_self_service_object_ids(user_or_group, klass)
    b_filtered_ids = get_belongsto_filter_object_ids(klass, rbac_filters['belongsto'])
    m_filtered_ids = get_managed_filter_object_ids(klass, scope, rbac_filters['managed'])
    d_filtered_ids = rbac_filters['ids_via_descendants']

    find_targets_filtered_by_ids(klass, scope, find_options, u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
  end

  def self.find_targets_with_user_group_rbac(klass, scope, _rbac_filters, find_options = {}, user_or_group = nil)
    if user_or_group && user_or_group.self_service?
      if klass == User && user_or_group.kind_of?(User)
        cond = ["id = ?", user_or_group.id]
      elsif klass == MiqGroup
        group_id = user_or_group.id if user_or_group.kind_of?(MiqGroup)
        group_id ||= user_or_group.current_group_id if user_or_group.kind_of?(User) && user_or_group.current_group
        cond = ["id = ?", group_id] if group_id
      else
        cond = nil
      end

      cond, incl = MiqExpression.merge_where_clauses_and_includes([find_options[:condition], cond].compact, [find_options[:include]].compact)
      targets = klass.all(find_options.except(:conditions, :include)).where(cond).includes(incl).references(incl)

      [targets, targets.length, targets.length]
    else
      find_targets_without_rbac(klass, scope, find_options)
    end
  end

  def self.find_options_for_tenant(klass, user_or_group, find_options = {})
    tenant_ids = klass.accessible_tenant_ids(user_or_group, accessible_tenant_ids_strategy(klass))
    return find_options if tenant_ids.empty?

    tenant_id_clause = {klass.table_name => {:tenant_id => tenant_ids}}
    find_options[:conditions] = MiqExpression.merge_where_clauses(find_options[:conditions], tenant_id_clause)
    find_options
  end

  def self.accessible_tenant_ids_strategy(klass)
    TENANT_ACCESS_STRATEGY[klass.to_s]
  end

  def self.find_targets_with_rbac(klass, scope, rbac_filters, find_options = {}, user_or_group = nil)
    find_options = find_options_for_tenant(klass, user_or_group, find_options) if klass.respond_to?(:scope_by_tenant?) && klass.scope_by_tenant?

    return find_targets_with_direct_rbac(klass, scope, rbac_filters, find_options, user_or_group)     if apply_rbac_to_class?(klass)
    return find_targets_with_indirect_rbac(klass, scope, rbac_filters, find_options, user_or_group)   if apply_rbac_to_associated_class?(klass)
    return find_targets_with_user_group_rbac(klass, scope, rbac_filters, find_options, user_or_group) if apply_user_group_rbac_to_class?(klass)
    find_targets_without_rbac(klass, scope, find_options)
  end

  def self.find_targets_without_rbac(_klass, scope, find_options = {})
    targets     = method_with_scope(scope, find_options)
    total_count = find_options[:limit] ? scope.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count : targets.length

    return targets, total_count, total_count
  end

  def self.minimum_columns_for(klass)
    columns = ['id']
    columns << 'type' if klass.column_names.include?('type') # STI classes will instantiate calling class without type column
    columns.join(', ')
  end

  def self.get_user_info(user, userid, miq_group, miq_group_id)
    user      ||= User.find_by_userid(userid) || User.current_user
    miq_group ||= MiqGroup.find_by_id(miq_group_id)
    if user && miq_group
      user.current_group = miq_group if user.miq_groups.include?(miq_group)
    end
    # for reports, user is currently nil, so use the group filter
    user_filters = user.try(:get_filters) || miq_group.try(:get_filters) || {}
    user_filters["managed"] ||= []

    [user, miq_group, user_filters]
  end

  def self.filtered(objects, options = {})
    if objects.present?
      Rbac.search(options.merge(:targets => objects, :results_format => :objects)).first
    else
      objects
    end
  end

  def self.find_via_descendants(descendants, method_name, klass)
    matches = []
    descendants.each do |object|
      match = object.send(method_name)
      match = [match] unless match.kind_of?(Array)
      match.each do |m|
        next unless m.kind_of?(klass)
        next if matches.include?(m)
        matches << m
      end
    end
    matches
  end

  def self.find_descendants(descendant_klass, options = {})
    search(options.merge(:class => descendant_klass, :results_format => :objects)).first
  end

  def self.ids_via_descendants(klass, descendant_types, options = {})
    objects = matches_via_descendants(klass, descendant_types, options)
    return nil if objects.blank?
    objects.collect(&:id)
  end

  def self.matches_via_descendants(klass, descendant_types, options = {})
    return nil if descendant_types.nil?

    matches = []
    descendant_types = [descendant_types] unless descendant_types.kind_of?(Hash) || descendant_types.kind_of?(Array)
    descendant_types.each do |descendant_type|
      descendant_klass, method_name = parse_descendant_type(descendant_type, klass)
      next if method_name.nil?

      descendants = find_descendants(descendant_klass, options)
      objects     = find_via_descendants(descendants, method_name, klass)
      matches.concat(objects)
    end

    matches.uniq
  end

  def self.lookup_method_for_descendant_class(klass, descendant_klass)
    key = "#{descendant_klass.base_class}::#{klass.base_class}"
    method_name = MATCH_VIA_DESCENDANT_RELATIONSHIPS[key]
    if method_name.nil?
      _log.warn "could not find method name for #{key}"
    end
    method_name
  end

  def self.parse_descendant_type(descendant_type, klass)
    if descendant_type.kind_of?(Array)
      descendant_klass, method_name = descendant_type
    else
      descendant_klass = descendant_type
    end

    descendant_klass = descendant_klass.constantize      if descendant_klass.kind_of?(String)
    descendant_klass = descendant_klass.to_s.constantize if descendant_klass.kind_of?(Symbol)

    method_name ||= lookup_method_for_descendant_class(klass, descendant_klass)
    return descendant_klass, method_name
  end

  def self.search(options = {})
    # => empty inputs - normal find with optional where_clause
    # => list if ids - :class is required for this format.
    # => list of objects
    # results are returned in the same format as the targets. for empty targets, the default result format is a list of ids.
    targets           = options.delete(:targets) || []

    # Support for using named_scopes in search. Supports scopes with or without args:
    # Example without args: :named_scope => :in_my_region
    # Example with args:    :named_scope => [in_region, 1]
    scope             = options.delete(:named_scope) || NO_SCOPE

    class_or_name     = options.delete(:class) { Object }
    conditions        = options.delete(:conditions)
    where_clause      = options.delete(:where_clause)
    sub_filter        = options.delete(:sub_filter)
    include_for_find  = options.delete(:include_for_find)
    search_filter     = options.delete(:filter)
    results_format    = options.delete(:results_format)

    user, miq_group, user_filters = get_user_info(options.delete(:user),
                                                  options.delete(:userid),
                                                  options.delete(:miq_group),
                                                  options.delete(:miq_group_id))
    tz                     = user.try(:get_timezone)
    attrs                  = {:user_filters => copy_hash(user_filters)}
    klass                  = class_or_name.kind_of?(Class) ? class_or_name : class_or_name.to_s.constantize
    ids_clause             = nil
    target_ids             = nil

    unless targets.empty?
      if targets.first.kind_of?(Numeric)
        target_ids       = targets
      else
        target_ids       = targets.collect(&:id)
        klass            = targets.first.class.base_class unless klass.respond_to?(:find)
        results_format ||= :objects
      end

      ids_clause = ["#{klass.table_name}.id IN (?)", target_ids] if klass.respond_to?(:table_name)
    end

    user_filters['ids_via_descendants'] = ids_via_descendants(rbac_class(klass), options.delete(:match_via_descendants), :user => user, :miq_group => miq_group)

    exp_sql, exp_includes, exp_attrs = search_filter.to_sql(tz) unless search_filter.nil? || klass.respond_to?(:instances_are_derived?)
    conditions, include_for_find = MiqExpression.merge_where_clauses_and_includes([conditions, sub_filter, where_clause, exp_sql, ids_clause], [include_for_find, exp_includes])

    attrs[:apply_limit_in_sql] = (exp_attrs.nil? || exp_attrs[:supported_by_sql]) && user_filters["belongsto"].blank?

    find_options = {:conditions => conditions, :include => include_for_find, :order => options[:order]}
    find_options.merge!(:limit => options[:limit], :offset => options[:offset]) if attrs[:apply_limit_in_sql]
    find_options[:ext_options] = options[:ext_options] if options[:ext_options] && klass.respond_to?(:instances_are_derived?) && klass.instances_are_derived?

    _log.debug("Find options: #{find_options.inspect}")

    if klass.respond_to?(:find)
      scope = apply_scope(klass, scope)
      targets, total_count, auth_count = find_targets_with_rbac(klass, scope, user_filters, find_options, user || miq_group)
    else
      total_count = targets.length
      auth_count  = targets.length
    end

    unless search_filter.nil?
      rejects     = targets.reject { |obj| self.matches_search_filters?(obj, search_filter, tz) }
      auth_count -= rejects.length
      targets -= rejects
    end

    if options[:limit] && !attrs[:apply_limit_in_sql]
      attrs[:target_ids_for_paging] = targets.collect(&:id) # Save ids of targets, since we have then all, to avoid going back to SQL for the next page
      offset = options[:offset].to_i
      targets = targets[offset..(offset + options[:limit].to_i - 1)]
    end

    # Preserve sort order of incoming target_ids
    if !target_ids.nil? && !options[:order]
      targets = targets.sort { |a, b| target_ids.index(a.id) <=> target_ids.index(b.id) }
    end

    attrs.merge!(:total_count => total_count, :auth_count => auth_count)

    results_format   = :objects if klass.respond_to?(:instances_are_derived?) && klass.instances_are_derived? # can't return ids if instances are derived from another source
    results_format ||= :ids

    targets = case results_format
              when :objects then targets
              when :ids     then targets.collect(&:id)
              else raise "unknown results format of '#{results_format.inspect}"
              end

    return targets, attrs
  end

  def self.method_with_scope(ar_scope, options)
    if ar_scope == VmdbDatabaseConnection || ar_scope == VmdbDatabaseSetting
      ar_scope.all
    elsif ar_scope < ActsAsArModel || (ar_scope.respond_to?(:instances_are_derived?) && ar_scope.instances_are_derived?)
      ar_scope.find(:all, options)
    else
      ar_scope.apply_legacy_finder_options(options)
    end
  end

  def self.apply_scope(klass, scope)
    scope_name = scope.to_miq_a.first
    if scope_name == NO_SCOPE
      klass
    else
      raise "Named scope '#{scope_name}' is not defined for class '#{klass.name}'" unless klass.respond_to?(scope_name)
      klass.send(*scope)
    end
  end

  def self.get_belongsto_matches(blist, klass)
    results = []
    blist.each do |bfilter|
      vcmeta_list = MiqFilter.belongsto2object_list(bfilter)
      next if vcmeta_list.empty?

      if klass == Storage
        vcmeta_list.reverse_each do |vcmeta|
          if vcmeta.respond_to?(:storages)
            results.concat(vcmeta.storages)
            break
          end
        end
      elsif klass == Host
        results.concat(get_belongsto_matches_for_host(vcmeta_list.last))
      else
        vcmeta_list.each { |vcmeta| results.push(vcmeta) if vcmeta.kind_of?(klass) }
        results.concat(vcmeta_list.last.descendants.select { |obj| obj.kind_of?(klass) })
      end
    end

    results.uniq
  end

  def self.get_belongsto_matches_for_host(vcmeta)
    subtree  = vcmeta.subtree
    clusters = subtree.select { |obj| obj.kind_of?(EmsCluster) }
    hosts    = subtree.select { |obj| obj.kind_of?(Host) }

    MiqPreloader.preload(clusters, :hosts)
    clusters.collect(&:hosts).flatten + hosts
  end

  def self.matches_search_filters?(obj, filter, tz)
    return true if filter.nil?
    expression = filter.to_ruby(tz)
    return true if expression.nil?
    substituted_expression = Condition.subst(expression, obj, {})
    return true if Condition.do_eval(substituted_expression)
    false
  end
end
