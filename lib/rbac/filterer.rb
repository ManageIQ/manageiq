module Rbac
  class Filterer
    # This list is used to detemine whether RBAC, based on assigned tags, should be applied for a class in a search that is based on the class.
    # Classes should be added to this list ONLY after:
    # 1. It has been added to the MiqExpression::BASE_TABLES list
    # 2. Tagging has been enabled in the UI
    # 3. Class contains acts_as_miq_taggable
    CLASSES_THAT_PARTICIPATE_IN_RBAC = %w(
      AvailabilityZone
      CloudTenant
      CloudVolume
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

    # key: descendant::klass
    # value:
    #   if it is a symbol/method_name:
    #     descendant.send(method_name) ==> klass
    #   if it is an array [klass_id, descendant_id]
    #     klass.where(klass_id => descendant.select(descendant_id))
    MATCH_VIA_DESCENDANT_RELATIONSHIPS = {
      "VmOrTemplate::ExtManagementSystem"      => [:id, :ems_id],
      "VmOrTemplate::Host"                     => [:id, :host_id],
      "VmOrTemplate::EmsCluster"               => [:id, :ems_cluster_id],
      "VmOrTemplate::EmsFolder"                => :parent_blue_folders,
      "VmOrTemplate::ResourcePool"             => :resource_pool,
      "ConfiguredSystem::ExtManagementSystem"  => :ext_management_system,
      "ConfiguredSystem::ConfigurationProfile" => [:id, :configuration_profile_id],
    }

    # These classes should accept any of the relationship_mixin methods including:
    #   :parent_ids
    #   :ancestor_ids
    #   :child_ids
    #   :sibling_ids
    #   :descendant_ids
    #   ...
    TENANT_ACCESS_STRATEGY = {
      'CloudSnapshot'          => :descendant_ids,
      'CloudTenant'            => :descendant_ids,
      'CloudVolume'            => :descendant_ids,
      'ExtManagementSystem'    => :ancestor_ids,
      'MiqAeNamespace'         => :ancestor_ids,
      'MiqGroup'               => :descendant_ids,
      'MiqRequest'             => :descendant_ids,
      'MiqRequestTask'         => nil, # tenant only
      'MiqTemplate'            => :ancestor_ids,
      'Provider'               => :ancestor_ids,
      'ServiceTemplateCatalog' => :ancestor_ids,
      'ServiceTemplate'        => :ancestor_ids,
      'Service'                => :descendant_ids,
      'Tenant'                 => :descendant_ids,
      'User'                   => :descendant_ids,
      'Vm'                     => :descendant_ids
    }

    include Vmdb::Logging

    def self.search(*args)
      new.search(*args)
    end

    def self.filtered(*args)
      new.filtered(*args)
    end

    def self.filtered_object(*args)
      new.filtered_object(*args)
    end

    def self.accessible_tenant_ids_strategy(klass)
      TENANT_ACCESS_STRATEGY[klass.base_model.to_s]
    end

    # @param  options filtering options
    # @option options :targets       [nil|Array<Numeric|Object>|scope] Objects to be filtered
    #   - an nil entry uses the optional where_clause
    #   - Array<Numeric> list if ids. :class is required. results are returned as ids
    #   - Array<Object> list of objects. results are returned as objects
    # @option options :named_scope   [Symbol|Array<String,Integer>] support for using named scope in search
    #     Example without args: :named_scope => :in_my_region
    #     Example with args:    :named_scope => [in_region, 1]
    # @option options :conditions    [Hash|String|Array<String>]
    # @option options :where_clause  []
    # @option options :sub_filter
    # @option options :include_for_find [Array<Symbol>]
    # @option options :filter

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
    # @option options :skip_count   [Boolean] (default: false)
    # @return [Array<Array<Object>,Hash>] list of object and the associated search options
    #   Array<Object> list of object in the same order as input targets if possible
    # @option attrs :auth_count [Numeric]
    # @option attrs :user_filters
    # @option attrs apply_limit_in_sql
    # @option attrs target_ids_for_paging
    def search(options = {})
      if options.key?(:targets) && options[:targets].kind_of?(Array) && options[:targets].empty?
        return [], {:auth_count => 0}
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

      klass             = to_class(options[:class])
      conditions        = options[:conditions]
      where_clause      = options[:where_clause]
      sub_filter        = options[:sub_filter]
      include_for_find  = options[:include_for_find]
      search_filter     = options[:filter]

      limit             = options[:limit]  || targets.try(:limit_value)
      offset            = options[:offset] || targets.try(:offset_value)
      order             = options[:order]  || targets.try(:order_values)

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
          # assume klass is passed in
        else
          target_ids       = targets.collect(&:id)
          klass            = targets.first.class.base_class unless klass.respond_to?(:find)
        end
        scope = apply_scope(klass, scope)

        ids_clause = ["#{klass.table_name}.id IN (?)", target_ids] if klass.respond_to?(:table_name)
      else # targets is a class_name, scope, class, or acts_as_ar_model class (VimPerformanceDaily in particular)
        targets = to_class(targets).all
        scope = apply_scope(targets, scope)

        unless klass.respond_to?(:find)
          klass = targets
          klass = klass.klass if klass.respond_to?(:klass)
          # working around MiqAeDomain not being in rbac_class
          klass = klass.base_class if klass.respond_to?(:base_class) && rbac_class(klass).nil? && rbac_class(klass.base_class)
        end
      end

      user_filters['match_via_descendants'] = to_class(options[:match_via_descendants])

      exp_sql, exp_includes, exp_attrs = search_filter.to_sql(tz) if search_filter && !klass.try(:instances_are_derived?)
      attrs[:apply_limit_in_sql] = (exp_attrs.nil? || exp_attrs[:supported_by_sql]) && user_filters["belongsto"].blank?

      # for belongs_to filters, scope_targets uses scope to make queries. want to remove limits for those.
      # if you note, the limits are put back into scope a few lines down from here
      scope = scope.except(:offset, :limit, :order)
      scope = scope_targets(klass, scope, user_filters, user, miq_group)
              .where(conditions).where(sub_filter).where(where_clause).where(exp_sql).where(ids_clause)
              .includes(include_for_find).includes(exp_includes)
              .order(order)

      scope = include_references(scope, klass, include_for_find, exp_includes)
      scope = scope.limit(limit).offset(offset) if attrs[:apply_limit_in_sql]
      targets = scope

      unless options[:skip_counts]
        auth_count = attrs[:apply_limit_in_sql] && limit ? targets.except(:offset, :limit, :order).count(:all) : targets.length
      end

      if search_filter && targets && (!exp_attrs || !exp_attrs[:supported_by_sql])
        rejects     = targets.reject { |obj| matches_search_filters?(obj, search_filter, tz) }
        auth_count -= rejects.length unless options[:skip_counts]
        targets -= rejects
      end

      if limit && !attrs[:apply_limit_in_sql]
        attrs[:target_ids_for_paging] = targets.collect(&:id) # Save ids of targets, since we have then all, to avoid going back to SQL for the next page
        offset = offset.to_i
        targets = targets[offset...(offset + limit.to_i)]
      end

      # Preserve sort order of incoming target_ids
      if !target_ids.nil? && !order
        targets = targets.sort_by { |a| target_ids.index(a.id) }
      end

      attrs[:auth_count] = auth_count unless options[:skip_counts]

      return targets, attrs
    end

    def include_references(scope, klass, include_for_find, exp_includes)
      ref_includes = Hash(include_for_find).merge(Hash(exp_includes))
      unless polymorphic_include?(klass, ref_includes)
        scope = scope.references(include_for_find).references(exp_includes)
      end
      scope
    end

    def polymorphic_include?(target_klass, includes)
      includes.keys.any? do |incld|
        reflection = target_klass.reflect_on_association(incld)
        reflection && reflection.polymorphic?
      end
    end

    def filtered(objects, options = {})
      Rbac.search(options.reverse_merge(:targets => objects, :skip_counts => true)).first
    end

    def filtered_object(object, options = {})
      filtered([object], options).first
    end

    private

    ##
    # Determine if permissions should be applied directly via klass
    # (klass directly participates in RBAC)
    #
    def apply_rbac_directly?(klass)
      CLASSES_THAT_PARTICIPATE_IN_RBAC.include?(safe_base_class(klass).name)
    end

    ##
    # Determine if permissions should be applied via an associated parent class of klass
    # If the klass is a metrics subclass, RBAC bases permissions checks on
    # the associated application model.  See #rbac_class method
    #
    def apply_rbac_through_association?(klass)
      klass != VimPerformanceDaily && (klass < MetricRollup || klass < Metric)
    end

    def safe_base_class(klass)
      klass = klass.base_class if klass.respond_to?(:base_class)
      klass
    end

    def rbac_class(scope)
      klass = scope.respond_to?(:klass) ? scope.klass : scope
      return klass if apply_rbac_directly?(klass)
      if apply_rbac_through_association?(klass)
        # Strip "Performance" off class name, which is the associated model
        # of that metric.
        # e.g. HostPerformance => Host
        #      VmPerformance   => VmOrTemplate
        return klass.name[0..-12].constantize.base_class
      end
      nil
    end

    def pluck_ids(targets)
      targets.pluck(:id) if targets
    end

    def get_self_service_objects(user, miq_group, klass)
      return nil if miq_group.nil? || !miq_group.self_service? || !(klass < OwnershipMixin)

      # for limited_self_service, use user's resources, not user.current_group's resources
      # for reports (user = nil), still use miq_group
      miq_group = nil if user && miq_group.limited_self_service?

      # Get the list of objects that are owned by the user or their LDAP group
      klass.user_or_group_owned(user, miq_group).except(:order)
    end

    def calc_filtered_ids(scope, user_filters, user, miq_group)
      klass = scope.respond_to?(:klass) ? scope.klass : scope
      u_filtered_ids = pluck_ids(get_self_service_objects(user, miq_group, klass))
      b_filtered_ids = get_belongsto_filter_object_ids(klass, user_filters['belongsto'])
      m_filtered_ids = pluck_ids(get_managed_filter_object_ids(scope, user_filters['managed']))
      d_filtered_ids = pluck_ids(matches_via_descendants(rbac_class(klass), user_filters['match_via_descendants'],
                                                         :user => user, :miq_group => miq_group))

      combine_filtered_ids(u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
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
    def combine_filtered_ids(u_filtered_ids, b_filtered_ids, m_filtered_ids, d_filtered_ids)
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

    # @param parent_class [Class] Class of parent (e.g. Host)
    # @param klass [Class] Class of child node (e.g. Vm)
    # @param scope [] scope for active records (e.g. Vm.archived)
    # @param filtered_ids [nil|Array<Integer>] ids for the parent class (e.g. [1,2,3] for host)
    # @return [Array<Array<Object>,Integer,Integer] targets, authorized count
    def scope_by_parent_ids(parent_class, scope, filtered_ids)
      if filtered_ids
        if (reflection = scope.reflections[parent_class.name.underscore])
          scope.where(reflection.foreign_key.to_sym => filtered_ids)
        else
          scope.where(:resource_type => parent_class.name, :resource_id => filtered_ids)
        end
      else
        scope
      end
    end

    def scope_by_ids(scope, filtered_ids)
      if filtered_ids
        scope.where(:id => filtered_ids)
      else
        scope
      end
    end

    def get_belongsto_filter_object_ids(klass, filter)
      return nil if !BELONGSTO_FILTER_CLASSES.include?(safe_base_class(klass).name) || filter.blank?
      get_belongsto_matches(filter, rbac_class(klass)).collect(&:id)
    end

    def get_managed_filter_object_ids(scope, filter)
      klass = scope.respond_to?(:klass) ? scope.klass : scope
      return nil if !TAGGABLE_FILTER_CLASSES.include?(safe_base_class(klass).name) || filter.blank?
      scope.find_tags_by_grouping(filter, :ns => '*').reorder(nil)
    end

    def scope_to_tenant(scope, user, miq_group)
      klass = scope.respond_to?(:klass) ? scope.klass : scope
      user_or_group = user || miq_group
      tenant_id_clause = klass.tenant_id_clause(user_or_group)

      tenant_id_clause ? scope.where(tenant_id_clause) : scope
    end

    ##
    # Main scoping method
    #
    def scope_targets(klass, scope, rbac_filters, user, miq_group)
      # Results are scoped by tenant if the TenancyMixin is included in the class,
      # with a few manual exceptions (User, Tenant). Note that the classes in
      # TENANT_ACCESS_STRATEGY are a consolidated list of them.
      if klass.respond_to?(:scope_by_tenant?) && klass.scope_by_tenant?
        scope = scope_to_tenant(scope, user, miq_group)
      end

      if apply_rbac_directly?(klass)
        filtered_ids = calc_filtered_ids(scope, rbac_filters, user, miq_group)
        scope_by_ids(scope, filtered_ids)
      elsif apply_rbac_through_association?(klass)
        # if subclasses of MetricRollup or Metric, use the associated
        # model to derive permissions from
        associated_class = rbac_class(scope)
        filtered_ids = calc_filtered_ids(associated_class, rbac_filters, user, miq_group)

        scope_by_parent_ids(associated_class, scope, filtered_ids)
      elsif klass == User && user.try!(:self_service?)
        # Self service users searching for users only see themselves
        scope.where(:id => user.id)
      elsif klass == MiqGroup && miq_group.try!(:self_service?)
        # Self Service users searching for groups only see their group
        scope.where(:id => miq_group.id)
      else
        scope
      end
    end

    def get_user_info(user, userid, miq_group, miq_group_id)
      user, miq_group = lookup_user_group(user, userid, miq_group, miq_group_id)
      [user, miq_group, lookup_user_filters(user || miq_group)]
    end

    def lookup_user_group(user, userid, miq_group, miq_group_id)
      user ||= (userid && User.find_by_userid(userid)) || User.current_user
      miq_group_id ||= miq_group.try!(:id)
      return [user, user.current_group] if user && user.current_group_id.to_s == miq_group_id.to_s

      if user
        if miq_group_id && (detected_group = user.miq_groups.detect { |g| g.id.to_s == miq_group_id.to_s })
          user.current_group = detected_group
        elsif miq_group_id && user.super_admin_user?
          user.current_group = miq_group || MiqGroup.find_by_id(miq_group_id)
        end
      else
        miq_group ||= miq_group_id && MiqGroup.find_by_id(miq_group_id)
      end
      [user, user.try(:current_group) || miq_group]
    end

    # for reports, user is currently nil, so use the group filter
    # the user.get_filters delegates to user.current_group anyway
    def lookup_user_filters(miq_group)
      filters = miq_group.try!(:get_filters).try!(:dup) || {}
      filters["managed"] ||= []
      filters["belongsto"] ||= []
      filters
    end

    # @param klass [Class] base_class found in CLASSES_THAT_PARTICIPATE_IN_RBAC
    # @option options :user [User]
    # @option options :miq_group [MiqGroup]
    def matches_via_descendants(klass, descendant_klass, options)
      if descendant_klass && (method_name = lookup_method_for_descendant_class(klass, descendant_klass))
        descendants = filtered(descendant_klass, options)
        if method_name.kind_of?(Array)
          klass_id, descendant_id = method_name
          klass.where(klass_id => descendants.select(descendant_id)).distinct
        else
          MiqPreloader.preload(descendants, method_name)
          descendants.flat_map { |object| object.send(method_name) }.grep(klass).uniq
        end
      end
    end

    def lookup_method_for_descendant_class(klass, descendant_klass)
      key = "#{descendant_klass.base_class}::#{klass.base_class}"
      MATCH_VIA_DESCENDANT_RELATIONSHIPS[key].tap do |method_name|
        _log.warn "could not find method name for #{key}" if method_name.nil?
      end
    end

    def to_class(klass)
      klass.kind_of?(String) || klass.kind_of?(Symbol) ? klass.to_s.constantize : klass
    end

    def apply_scope(klass, scope)
      klass = klass.all
      scope_name = Array.wrap(scope).first
      if scope_name.nil?
        klass
      elsif klass.nil? || !klass.respond_to?(scope_name)
        class_name = klass.nil? ? "Object" : klass.name
        raise _("Named scope '%{scope_name}' is not defined for class '%{class_name}'") % {:scope_name => scope_name,
                                                                                           :class_name => class_name}
      else
        klass.send(*scope)
      end
    end

    def get_belongsto_matches(blist, klass)
      return get_belongsto_matches_for_host(blist) if klass == Host
      return get_belongsto_matches_for_storage(blist) if klass == Storage
      association_name = klass.base_model.to_s.tableize

      blist.flat_map do |bfilter|
        vcmeta_list = MiqFilter.belongsto2object_list(bfilter)
        next [] if vcmeta_list.empty?
        # typically, this is the only one we want:
        vcmeta = vcmeta_list.last

        if [ExtManagementSystem, Host].any? { |x| vcmeta.kind_of?(x) } && klass <= VmOrTemplate
          vcmeta.send(association_name).to_a
        else
          vcmeta_list.grep(klass) + vcmeta.descendants.grep(klass)
        end
      end.uniq
    end

    def get_belongsto_matches_for_host(blist)
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

    def get_belongsto_matches_for_storage(blist)
      sources = blist.map do |bfilter|
        MiqFilter.belongsto2object_list(bfilter).reverse.detect { |v| v.respond_to?(:storages) }
      end.select(&:present?)
      MiqPreloader.preload_and_map(sources, :storages)
    end

    def matches_search_filters?(obj, filter, tz)
      filter.nil? || filter.lenient_evaluate(obj, tz)
    end
  end
end
