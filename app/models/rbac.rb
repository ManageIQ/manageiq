module Rbac
  # This list is used to detemine whether RBAC, based on assigned tags, should be applied for a class in a search that is based on the class.
  # Classes should be added to this list ONLY after:
  # 1. It has been added to the MiqExpression::BASE_TABLES list
  # 2. Tagging has been enabled in the UI
  # 3. Class contains acts_as_miq_taggable
  CLASSES_THAT_PARTICIPATE_IN_RBAC = %w(
    AvailabilityZone
    CloudTenant
    ConfigurationProfile
    ConfiguredSystem
    Container
    ContainerGroup
    ContainerImage
    ContainerImageRegistry
    ContainerNode
    ContainerProject
    ContainerReplicator
    ContainerRoute
    ContainerService
    EmsCluster
    EmsFolder
    ExtManagementSystem
    Flavor
    Host
    MiqCimInstance
    OrchestrationTemplate
    OrchestrationStack
    ResourcePool
    SecurityGroup
    Service
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
    "VmOrTemplate::ExtManagementSystem"      => :ext_management_system,
    "VmOrTemplate::Host"                     => :host,
    "VmOrTemplate::EmsCluster"               => :ems_cluster,
    "VmOrTemplate::EmsFolder"                => :parent_blue_folders,
    "VmOrTemplate::ResourcePool"             => :resource_pool,
    "ConfiguredSystem::ExtManagementSystem"  => :ext_management_system,
    "ConfiguredSystem::ConfigurationProfile" => :configuration_profile
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
    'MiqRequest'             => :descendant_ids,
    'MiqRequestTask'         => nil, # tenant only
    'MiqTemplate'            => :ancestor_ids,
    'Provider'               => :ancestor_ids,
    'ServiceTemplateCatalog' => :ancestor_ids,
    'ServiceTemplate'        => :ancestor_ids,
    'Service'                => :descendant_ids,
    'Tenant'                 => :descendant_ids,
    'Vm'                     => :descendant_ids
  }

  ########################################################################################
  # RBAC is:
  #   Self-Service CIs OR (ManagedFilters CIs AND BelongsToFilters CIs)
  #     ManagedFilters   is: ManagedFilters.any?   { |f| matched_filter(f) }
  #     BelongsToFilters is: BelongsToFilters.any? { |f| matched_filter(f) }
  ########################################################################################

  def self.apply_user_group_rbac_to_class?(klass, miq_group)
    [User, MiqGroup].include?(klass) && miq_group.try!(:self_service?)
  end

  def self.safe_base_class(klass)
    klass = klass.base_class if klass.respond_to?(:base_class)
    klass
  end

  def self.apply_rbac_to_class?(klass)
    CLASSES_THAT_PARTICIPATE_IN_RBAC.include?(safe_base_class(klass).name)
  end

  def self.apply_rbac_to_associated_class?(klass)
    return false if [Metric, MetricRollup, VimPerformanceDaily].include?(klass)
    klass < MetricRollup || klass < Metric
  end

  def self.rbac_class(scope)
    klass = scope.respond_to?(:klass) ? scope.klass : scope
    return klass if apply_rbac_to_class?(klass)
    if apply_rbac_to_associated_class?(klass)
      return klass.name[0..-12].constantize.base_class # e.g. VmPerformance => VmOrTemplate
    end
    nil
  end

  def self.pluck_ids(targets)
    targets.pluck(:id) if targets
  end

  def self.get_self_service_objects(user, miq_group, klass)
    return nil if miq_group.nil? || !miq_group.self_service? || !(klass < OwnershipMixin)

    # for limited_self_service, use user's resources, not user.current_group's resources
    # for reports (user = nil), still use miq_group
    miq_group = nil if user && miq_group.limited_self_service?

    # Get the list of objects that are owned by the user or their LDAP group
    klass.user_or_group_owned(user, miq_group).except(:order)
  end

  def self.calc_filtered_ids(scope, user_filters, user, miq_group)
    klass = scope.respond_to?(:klass) ? scope.klass : scope
    u_filtered_ids = pluck_ids(get_self_service_objects(user, miq_group, klass))
    b_filtered_ids = get_belongsto_filter_object_ids(klass, user_filters['belongsto'])
    m_filtered_ids = pluck_ids(get_managed_filter_object_ids(scope, user_filters['managed']))
    d_filtered_ids = pluck_ids(matches_via_descendants(rbac_class(klass), user_filters['match_via_descendants'],
                                                       :user => user, :miq_group => miq_group))

    filtered_ids = combine_filtered_ids(u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
    [filtered_ids, u_filtered_ids]
  end

  #
  # Algorithm: filter = u_filtered_ids UNION (b_filtered_ids INTERSECTION m_filtered_ids)
  #            filter = filter UNION d_filtered_ids if filter is not nil
  #
  # a nil as input for any field means it does not apply
  # a nil as output means there is not filter
  #
  # @param u_filtered_ids [nil|Array<Integer>] self service user owned objects
  # @param b_filtered_ids [nil|Array<Integer>] objects that belong to parent
  # @param m_filtered_ids [nil|Array<Integer>] managed filter object ids
  # @param d_filtered_ids [nil|Array<Integer>] ids from descendants
  # @return nil if filters do not aply
  # @return [Array<Integer>] target ids for filter
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

  def self.find_targets_with_indirect_rbac(scope, rbac_filters, find_options, user, miq_group)
    parent_class = rbac_class(scope)
    filtered_ids, _ = calc_filtered_ids(parent_class, rbac_filters, user, miq_group)

    find_targets_filtered_by_parent_ids(parent_class, scope, find_options, filtered_ids)
  end

  def self.total_scope(scope, extra_target_ids, conditions, includes)
    if conditions && extra_target_ids
      scope = scope.where(conditions).or(scope.where(:id => extra_target_ids))
    elsif conditions
      scope = scope.where(conditions)
    elsif extra_target_ids
      scope = scope.where(:id => extra_target_ids)
    end

    scope.includes(includes).references(includes)
  end

  # @param parent_class [Class] Class of parent (e.g. Host)
  # @param klass [Class] Class of child node (e.g. Vm)
  # @param scope [] scope for active records (e.g. Vm.archived)
  # @param find_options [Hash<Symbol,String|Array>] options for active record conditions
  # @option find_options :conditions [String|Hash|Array] active record where conditions for primary records (e.g. { "vms.archived" => true} )
  # @param filtered_ids [nil|Array<Integer>] ids for the parent class (e.g. [1,2,3] for host)
  # @return [Array<Array<Object>,Integer,Integer] targets, total count, authorized count
  def self.find_targets_filtered_by_parent_ids(parent_class, scope, find_options, filtered_ids)
    total_count = scope.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count
    if filtered_ids
      reflection = scope.reflections[parent_class.name.underscore]
      if reflection
        ids_clause = ["#{scope.table_name}.#{reflection.foreign_key} IN (?)", filtered_ids]
      else
        ids_clause = ["#{scope.table_name}.resource_type = ? AND #{scope.table_name}.resource_id IN (?)", parent_class.name, filtered_ids]
      end

      find_options[:conditions] = MiqExpression.merge_where_clauses(find_options[:conditions], ids_clause)
      _log.debug("New Find options: #{find_options.inspect}")
    end
    targets     = method_with_scope(scope, find_options)
    auth_count  = scope.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count

    return targets, total_count, auth_count
  end

  def self.find_targets_filtered_by_ids(scope, find_options, u_filtered_ids, filtered_ids)
    total_count  = total_scope(scope, u_filtered_ids, find_options[:conditions], find_options[:include]).count
    if filtered_ids
      ids_clause  = ["#{scope.table_name}.id IN (?)", filtered_ids]
      find_options[:conditions] = MiqExpression.merge_where_clauses(find_options[:conditions], ids_clause)
      _log.debug("New Find options: #{find_options.inspect}")
    end
    targets     = method_with_scope(scope, find_options)
    auth_count  = targets.except(:offset, :limit, :order).count(:all)

    return targets, total_count, auth_count
  end

  def self.get_belongsto_filter_object_ids(klass, filter)
    return nil if !BELONGSTO_FILTER_CLASSES.include?(safe_base_class(klass).name) || filter.blank?
    get_belongsto_matches(filter, rbac_class(klass)).collect(&:id)
  end

  def self.get_managed_filter_object_ids(scope, filter)
    klass = scope.respond_to?(:klass) ? scope.klass : scope
    return nil if !TAGGABLE_FILTER_CLASSES.include?(safe_base_class(klass).name) || filter.blank?
    scope.find_tags_by_grouping(filter, :ns => '*').reorder(nil)
  end

  def self.find_targets_with_direct_rbac(scope, rbac_filters, find_options, user, miq_group)
    filtered_ids, u_filtered_ids = calc_filtered_ids(scope, rbac_filters, user, miq_group)
    find_targets_filtered_by_ids(scope, find_options, u_filtered_ids, filtered_ids)
  end

  def self.find_targets_with_user_group_rbac(scope, _rbac_filters, find_options, user, miq_group)
    klass = scope.respond_to?(:klass) ? scope.klass : scope
    if klass == User && user
      cond = {:id => user.id}
    elsif klass == MiqGroup
      cond = {:id => miq_group.id}
    end

    targets = klass.where(cond).where(find_options[:condition])
                .includes(find_options[:include]).references(find_options[:include])
                .group(find_options[:group]).order(find_options[:order])
                .offset(find_options[:offset]).limit(find_options[:limit]).to_a

    [targets, targets.length, targets.length]
  end

  def self.find_options_for_tenant(scope, user, miq_group, find_options)
    klass = scope.respond_to?(:klass) ? scope.klass : scope
    user_or_group = user || miq_group
    tenant_id_clause = klass.tenant_id_clause(user_or_group)

    find_options[:conditions] = MiqExpression.merge_where_clauses(find_options[:conditions], tenant_id_clause) if tenant_id_clause
    find_options
  end

  def self.accessible_tenant_ids_strategy(klass)
    TENANT_ACCESS_STRATEGY[klass.base_model.to_s]
  end

  def self.find_targets_with_rbac(klass, scope, rbac_filters, find_options, user, miq_group)
    if klass.respond_to?(:scope_by_tenant?) && klass.scope_by_tenant?
      find_options = find_options_for_tenant(scope, user, miq_group, find_options)
    end

    if apply_rbac_to_class?(klass)
      find_targets_with_direct_rbac(scope, rbac_filters, find_options, user, miq_group)
    elsif apply_rbac_to_associated_class?(klass)
      find_targets_with_indirect_rbac(scope, rbac_filters, find_options, user, miq_group)
    elsif apply_user_group_rbac_to_class?(klass, miq_group)
      find_targets_with_user_group_rbac(scope, rbac_filters, find_options, user, miq_group)
    else
      find_targets_without_rbac(scope, find_options)
    end
  end

  def self.find_targets_without_rbac(scope, find_options)
    targets     = method_with_scope(scope, find_options)
    total_count = find_options[:limit] ? scope.where(find_options[:conditions]).includes(find_options[:include]).references(find_options[:include]).count : targets.length

    return targets, total_count, total_count
  end

  def self.get_user_info(user, userid, miq_group, miq_group_id)
    user      ||= User.find_by_userid(userid) || User.current_user
    miq_group ||= MiqGroup.find_by_id(miq_group_id)
    if user && miq_group
      user.current_group = miq_group if user.miq_groups.include?(miq_group)
    end
    miq_group ||= user.try(:current_group)
    # for reports, user is currently nil, so use the group filter
    user_filters = user.try(:get_filters) || miq_group.try(:get_filters) || {}
    user_filters = user_filters.dup
    user_filters["managed"] ||= []
    user_filters["belongsto"] ||= []

    [user, miq_group, user_filters]
  end

  def self.filtered(objects, options = {})
    if objects.nil?
      Vmdb::Deprecation.deprecation_warning("objects = nil",
                                            "use [] to get an empty result back. nil will return all records",
                                            caller(0)) unless Rails.env.production?
    end
    Rbac.search(options.merge(:targets => objects, :results_format => :objects, :empty_means_empty => true)).first
  end

  # @param klass [Class] base_class found in CLASSES_THAT_PARTICIPATE_IN_RBAC
  # @option options :user [User]
  # @option options :miq_group [MiqGroup]
  def self.matches_via_descendants(klass, descendant_klass, options)
    if descendant_klass && (method_name = lookup_method_for_descendant_class(klass, descendant_klass))
      descendants = filtered(descendant_klass, options)
      MiqPreloader.preload(descendants, method_name)
      descendants.flat_map { |object| object.send(method_name) }.grep(klass).uniq
    end
  end

  def self.lookup_method_for_descendant_class(klass, descendant_klass)
    key = "#{descendant_klass.base_class}::#{klass.base_class}"
    MATCH_VIA_DESCENDANT_RELATIONSHIPS[key].tap do |method_name|
      _log.warn "could not find method name for #{key}" if method_name.nil?
    end
  end

  def self.to_class(klass)
    klass.kind_of?(String) || klass.kind_of?(Symbol) ? klass.to_s.constantize : klass
  end

  # @param  options filtering options
  # @option options :targets       [nil|Array<Numeric|Object>|scope] Objects to be filtered
  #   - an nil entry uses the optional where_clause
  #   - Array<Numeric> list if ids. :class is required. results are returned as ids
  #   - Array<Object> list of objects. results are returned as objects
  # @option options :named_scope   [Symbol|Array<String,Integer>] support for using named scope in search
  #     Example without args: :named_scope => :in_my_region
  #     Example with args:    :named_scope => [in_region, 1]
  # @option options :class_or_name [Class|String]
  # @option options :conditions    [Hash|String|Array<String>]
  # @option options :where_clause  []
  # @option options :sub_filter
  # @option options :include_for_find [Array<Symbol>]
  # @option options :filter
  # @option options :results_format [:id, :objects] (default: for object targets, :object, otherwise :id)

  # @option options :user         [User]     (default: current_user)
  # @option options :userid       [String]   User#userid (not user_id)
  # @option options :miq_group    [MiqGroup] (default: current_user.current_group)
  # @option options :miq_group_id [Numeric]
  # @option options :match_via_descendants [Hash]
  # @option options :order        [Numeric] (default: no order)
  # @option options :limit        [Numeric] (default: no limit)
  # @option options :offset       [Numeric] (default: no offset)
  # @option options :apply_limit_in_sql [Boolean]
  # @option options :ext_options
  # @return [Array<Array<Numeric|Object>,Hash>] list of object and the associated search options
  #   Array<Numeric|Object> list of object in the same order as input targets if possible
  # @option attrs :total_count [Numeric]
  # @option attrs :auth_count [Numeric]
  # @option attrs :user_filters
  # @option attrs apply_limit_in_sql
  # @option attrs target_ids_for_paging

  def self.search(options = {})
    # now:   search(:targets => [],  :class => Vm) searches Vms
    # later: search(:targets => [],  :class => Vm) returns []
    #        search(:targets => nil, :class => Vm) will always search Vms
    if options.key?(:targets) && options[:targets].kind_of?(Array) && options[:targets].empty?
      return [], {:total_count => 0} if options[:empty_means_empty]

      Vmdb::Deprecation.deprecation_warning(":targets => []", "use :targets => nil to search all records",
                                            caller(0)) unless Rails.env.production?
      options[:targets] = nil
    end
    # => empty inputs - normal find with optional where_clause
    # => list if ids - :class is required for this format.
    # => list of objects
    # results are returned in the same format as the targets. for empty targets, the default result format is a list of ids.
    targets           = options[:targets]

    # Support for using named_scopes in search. Supports scopes with or without args:
    # Example without args: :named_scope => :in_my_region
    # Example with args:    :named_scope => [in_region, 1]
    scope             = options[:named_scope]

    klass             = to_class(options[:class]) || Object
    conditions        = options[:conditions]
    where_clause      = options[:where_clause]
    sub_filter        = options[:sub_filter]
    include_for_find  = options[:include_for_find]
    search_filter     = options[:filter]
    results_format    = options[:results_format]

    user, miq_group, user_filters = get_user_info(options[:user],
                                                  options[:userid],
                                                  options[:miq_group],
                                                  options[:miq_group_id])
    tz                     = user.try(:get_timezone)
    attrs                  = {:user_filters => copy_hash(user_filters)}
    ids_clause             = nil
    target_ids             = nil

    if targets.nil?
      scope = apply_scope(klass, scope)
    elsif targets.kind_of?(Array)
      if targets.first.kind_of?(Numeric)
        target_ids = targets
      else
        target_ids       = targets.collect(&:id)
        klass            = targets.first.class.base_class unless klass.respond_to?(:find)
        results_format ||= :objects
      end
      scope = apply_scope(klass, scope)

      ids_clause = ["#{klass.table_name}.id IN (?)", target_ids] if klass.respond_to?(:table_name)
    else # targets is a scope, class, or AASM class (VimPerformanceDaily in particular)
      targets = to_class(targets)
      targets = targets.all if targets < ActiveRecord::Base

      results_format ||= :objects
      scope = apply_scope(targets, scope)

      unless klass.respond_to?(:find)
        klass = targets
        klass = klass.klass if klass.respond_to?(:klass)
        # working around MiqAeDomain not being in rbac_class
        klass = klass.base_class if klass.respond_to?(:base_class) && rbac_class(klass).nil? && rbac_class(klass.base_class)
      end
    end

    user_filters['match_via_descendants'] = to_class(options[:match_via_descendants])

    exp_sql, exp_includes, exp_attrs = search_filter.to_sql(tz) if search_filter && !klass.respond_to?(:instances_are_derived?)
    conditions, include_for_find = MiqExpression.merge_where_clauses_and_includes([conditions, sub_filter, where_clause, exp_sql, ids_clause], [include_for_find, exp_includes])

    attrs[:apply_limit_in_sql] = (exp_attrs.nil? || exp_attrs[:supported_by_sql]) && user_filters["belongsto"].blank?

    find_options = {:conditions => conditions, :include => include_for_find, :order => options[:order]}
    find_options.merge!(:limit => options[:limit], :offset => options[:offset]) if attrs[:apply_limit_in_sql]
    find_options[:ext_options] = options[:ext_options] if options[:ext_options] && klass.respond_to?(:instances_are_derived?) && klass.instances_are_derived?

    _log.debug("Find options: #{find_options.inspect}")

    if klass.respond_to?(:find)
      targets, total_count, auth_count = find_targets_with_rbac(klass, scope, user_filters, find_options, user, miq_group)
    else
      total_count = targets.length
      auth_count  = targets.length
    end

    if search_filter && targets && (!exp_attrs || !exp_attrs[:supported_by_sql])
      rejects     = targets.reject { |obj| self.matches_search_filters?(obj, search_filter, tz) }
      auth_count -= rejects.length
      targets -= rejects
    end

    if options[:limit] && !attrs[:apply_limit_in_sql]
      attrs[:target_ids_for_paging] = targets.collect(&:id) # Save ids of targets, since we have then all, to avoid going back to SQL for the next page
      offset = options[:offset].to_i
      targets = targets[offset...(offset + options[:limit].to_i)]
    end

    # Preserve sort order of incoming target_ids
    if !target_ids.nil? && !options[:order]
      targets = targets.sort_by { |a| target_ids.index(a.id) }
    end

    attrs.merge!(:total_count => total_count, :auth_count => auth_count)

    results_format   = :objects if klass.respond_to?(:instances_are_derived?) && klass.instances_are_derived? # can't return ids if instances are derived from another source
    results_format ||= :ids

    targets = case results_format
              when :objects then targets
              when :ids     then targets.collect(&:id)
              else raise _("unknown results format of '%{format_type}") % {:format_type => results_format.inspect}
              end

    return targets, attrs
  end

  def self.method_with_scope(ar_scope, options)
    if ar_scope.respond_to?(:instances_are_derived?) ? ar_scope.instances_are_derived? : (ar_scope < ActsAsArModel)
      ar_scope.all(options)
    else
      ar_scope.apply_legacy_finder_options(options)
    end
  end

  def self.apply_scope(klass, scope)
    scope_name = Array.wrap(scope).first
    if scope_name.nil?
      klass
    else
      unless klass.respond_to?(scope_name)
        raise _("Named scope '%{scope_name}' is not defined for class '%{class_name}'") % {:scope_name => scope_name,
                                                                                           :class_name => klass.name}
      end
      klass.send(*scope)
    end
  end

  def self.get_belongsto_matches(blist, klass)
    return get_belongsto_matches_for_host(blist, klass) if klass == Host
    return get_belongsto_matches_for_storage(blist, klass) if klass == Storage
    association_name = klass.base_model.to_s.tableize

    blist.flat_map do |bfilter|
      vcmeta_list = MiqFilter.belongsto2object_list(bfilter)
      next [] if vcmeta_list.empty?
      # typically, this is the only one we want:
      vcmeta = vcmeta_list.last

      if vcmeta.kind_of?(Host) && klass <= VmOrTemplate
        vcmeta.send(association_name).to_a
      else
        vcmeta_list.grep(klass) + vcmeta.descendants.grep(klass)
      end
    end.uniq
  end

  def self.get_belongsto_matches_for_host(blist, klass)
    clusters = []
    hosts = []
    blist.each do |bfilter|
      vcmeta = MiqFilter.belongsto2object(bfilter)
      next unless vcmeta

      subtree  = vcmeta.subtree
      clusters += subtree.grep(EmsCluster)
      hosts    += subtree.grep(Host)
    end
    MiqPreloader.preload_and_map(clusters, :hosts) + hosts
  end

  def self.get_belongsto_matches_for_storage(blist, klass)
    blist.flat_map do |bfilter|
      vcmeta_list = MiqFilter.belongsto2object_list(bfilter)
      vcmeta = vcmeta_list.reverse.detect { |v| v.respond_to?(:storages) }
      vcmeta ? vcmeta.storages : []
    end
  end

  def self.matches_search_filters?(obj, filter, tz)
    return true if filter.nil?
    expression = filter.to_ruby(tz)
    return true if expression.nil?
    substituted_expression = Condition.subst(expression, obj)
    return true if Condition.do_eval(substituted_expression)
    false
  end
end
