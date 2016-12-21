class MiqExpression
  require_nested :Tag
  include Vmdb::Logging
  attr_accessor :exp, :context_type, :preprocess_options

  BASE_TABLES = %w(
    AuditEvent
    AvailabilityZone
    BottleneckEvent
    ChargebackVm
    ChargebackContainerProject
    ChargebackContainerImage
    CloudResourceQuota
    CloudTenant
    CloudVolume
    Compliance
    ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem
    ManageIQ::Providers::ConfigurationManager
    Container
    ContainerGroup
    ContainerImage
    ContainerImageRegistry
    ContainerNode
    ContainerProject
    ContainerReplicator
    ContainerRoute
    ContainerService
    ContainerTemplate
    ManageIQ::Providers::CloudManager
    EmsCluster
    EmsClusterPerformance
    EmsEvent
    ManageIQ::Providers::InfraManager
    ExtManagementSystem
    ExtManagementSystemPerformance
    Flavor
    Host
    HostAggregate
    HostPerformance
    MiqGroup
    MiqRegion
    MiqRequest
    MiqServer
    MiqTemplate
    MiqWorker
    OntapFileShare
    OntapLogicalDisk
    OntapStorageSystem
    OntapStorageVolume
    OntapVolumeMetricsRollup
    OrchestrationStack
    OrchestrationTemplate
    PolicyEvent
    ResourcePool
    SecurityGroup
    Service
    ServiceTemplate
    Storage
    StorageFile
    StoragePerformance
    Switch
    ManageIQ::Providers::CloudManager::Template
    ManageIQ::Providers::InfraManager::Template
    Tenant
    User
    VimPerformanceTrend
    Vm
    ManageIQ::Providers::CloudManager::Vm
    ManageIQ::Providers::InfraManager::Vm
    VmPerformance
    Zone
  )

  INCLUDE_TABLES = %w(
    advanced_settings
    audit_events
    availability_zones
    cloud_networks
    cloud_resource_quotas
    cloud_tenants
    compliances
    compliance_details
    computer_systems
    configuration_profiles
    configuration_managers
    configured_systems
    containers
    container_groups
    container_projects
    container_images
    container_nodes
    customization_scripts
    customization_script_media
    customization_script_ptables
    disks
    ems_events
    ems_clusters
    ems_custom_attributes
    evm_owners
    event_logs
    ext_management_systems
    filesystem_drivers
    filesystems
    firewall_rules
    flavors
    groups
    guest_applications
    guest_devices
    hardwares
    hosts
    host_aggregates
    host_services
    kernel_drivers
    key_pairs
    lans
    last_compliances
    linux_initprocesses
    miq_actions
    miq_approval_stamps
    miq_custom_attributes
    miq_policy_sets
    miq_provisions
    miq_regions
    miq_requests
    miq_scsi_luns
    miq_servers
    miq_workers
    ontap_concrete_extents
    ontap_file_shares
    ontap_logical_disks
    ontap_plex_extents
    ontap_raid_group_extents
    ontap_storage_systems
    ontap_storage_volumes
    openscap_results
    openscap_rule_results
    orchestration_stack_outputs
    orchestration_stack_parameters
    orchestration_stack_resources
    orchestration_templates
    operating_system_flavors
    partitions
    ports
    processes
    miq_provision_templates
    miq_provision_vms
    miq_templates
    networks
    nics
    operating_systems
    patches
    registry_items
    resource_pools
    security_groups
    service_templates
    services
    snapshots
    stacks
    storages
    storage_adapters
    storage_files
    switches
    tenant_quotas
    users
    vms
    volumes
    win32_services
    zones
    storage_systems
    file_systems
    hosted_file_shares
    file_shares
    logical_disks
    storage_volumes
    base_storage_extents
    top_storage_extents
  )

  EXCLUDE_COLUMNS = %w(
    ^.*_id$
    ^id$
    ^min_derived_storage.*$
    ^max_derived_storage.*$
    assoc_ids
    capture_interval
    filters
    icon

    intervals_in_rollup

    max_cpu_ready_delta_summation
    max_cpu_system_delta_summation
    max_cpu_used_delta_summation
    max_cpu_wait_delta_summation
    max_derived_cpu_available
    max_derived_cpu_reserved
    max_derived_memory_available
    max_derived_memory_reserved

    memory_usage

    min_cpu_ready_delta_summation
    min_cpu_system_delta_summation
    min_cpu_used_delta_summation
    min_cpu_wait_delta_summation
    min_derived_memory_available
    min_derived_memory_reserved
    min_derived_cpu_available
    min_derived_cpu_reserved

    min_max

    options
    password
    policy_settings
    ^reserved$
    resource_id
    settings
    tag_names
    v_qualified_desc
  )

  EXCLUDE_EXCEPTIONS = %w(
    capacity_profile_1_memory_per_vm_with_min_max
    capacity_profile_1_vcpu_per_vm_with_min_max
    capacity_profile_2_memory_per_vm_with_min_max
    capacity_profile_2_vcpu_per_vm_with_min_max
    chain_id
    guid
    openscap_id
  )

  TAG_CLASSES = {
    'ManageIQ::Providers::CloudManager'           => 'ext_management_system',
    'EmsCluster'                                  => 'ems_cluster',
    'ManageIQ::Providers::InfraManager'           => 'ext_management_system',
    'ManageIQ::Providers::ContainerManager'       => 'ext_management_system',
    'ExtManagementSystem'                         => 'ext_management_system',
    'Host'                                        => 'host',
    'MiqGroup'                                    => 'miq_group',
    'MiqTemplate'                                 => 'miq_template',
    'ResourcePool'                                => 'resource_pool',
    'Service'                                     => 'service',
    'Storage'                                     => 'storage',
    'ManageIQ::Providers::CloudManager::Template' => 'miq_template',
    'ManageIQ::Providers::InfraManager::Template' => 'miq_template',
    'User'                                        => 'user',
    'Vm'                                          => 'vm',
    'VmOrTemplate'                                => 'vm',
    'ManageIQ::Providers::CloudManager::Vm'       => 'vm',
    'ManageIQ::Providers::InfraManager::Vm'       => 'vm',
    'ContainerProject'                            => 'container_project',
    'ContainerImage'                              => 'container_image'
  }
  EXCLUDE_FROM_RELATS = {
    "ManageIQ::Providers::CloudManager" => ["hosts", "ems_clusters", "resource_pools"]
  }

  FORMAT_SUB_TYPES = {
    :boolean     => {
      :short_name => _("Boolean"),
      :title      => _("Enter true or false")
    },
    :bytes       => {
      :short_name => _("Bytes"),
      :title      => _("Enter the number of Bytes"),
      :units      => [
        [_("Bytes"), :bytes],
        [_("KB"), :kilobytes],
        [_("MB"), :megabytes],
        [_("GB"), :gigabytes],
        [_("TB"), :terabytes]
      ]
    },
    :date        => {
      :short_name => _("Date"),
      :title      => _("Click to Choose a Date")
    },
    :datetime    => {
      :short_name => _("Date / Time"),
      :title      => _("Click to Choose a Date / Time")
    },
    :float       => {
      :short_name => _("Number"),
      :title      => _("Enter a Number (like 12.56)")
    },
    :gigabytes   => {
      :short_name => _("Gigabytes"),
      :title      => _("Enter the number of Gigabytes")
    },
    :integer     => {
      :short_name => _("Integer"),
      :title      => _("Enter an Integer")
    },
    :kbps        => {
      :short_name => _("KBps"),
      :title      => _("Enter the Kilobytes per second")
    },
    :kilobytes   => {
      :short_name => _("Kilobytes"),
      :title      => _("Enter the number of Kilobytes")
    },
    :megabytes   => {
      :short_name => _("Megabytes"),
      :title      => _("Enter the number of Megabytes")
    },
    :mhz         => {
      :short_name => _("Mhz"),
      :title      => _("Enter the number of Megahertz")
    },
    :numeric_set => {
      :short_name => _("Number List"),
      :title      => _("Enter a list of numbers separated by commas")
    },
    :percent     => {
      :short_name => _("Percent"),
      :title      => _("Enter a Percent (like 12.5)"),
    },
    :regex       => {
      :short_name => _("Regular Expression"),
      :title      => _("Enter a Regular Expression")
    },
    :string      => {
      :short_name => _("Text String"),
      :title      => _("Enter a Text String")
    },
    :string_set  => {
      :short_name => _("String List"),
      :title      => _("Enter a list of text strings separated by commas")
    }
  }
  FORMAT_SUB_TYPES[:fixnum] = FORMAT_SUB_TYPES[:decimal] = FORMAT_SUB_TYPES[:integer]
  FORMAT_SUB_TYPES[:mhz_avg] = FORMAT_SUB_TYPES[:mhz]
  FORMAT_SUB_TYPES[:text] = FORMAT_SUB_TYPES[:string]
  FORMAT_BYTE_SUFFIXES = FORMAT_SUB_TYPES[:bytes][:units].inject({}) { |h, (v, k)| h[k] = v; h }
  BYTE_FORMAT_WHITELIST = Hash[FORMAT_BYTE_SUFFIXES.keys.collect(&:to_s).zip(FORMAT_BYTE_SUFFIXES.keys)]

  def initialize(exp, ctype = nil)
    @exp = exp
    @context_type = ctype

    load_virtual_custom_attributes
  end

  def load_virtual_custom_attributes
    return unless @exp

    custom_attributes_group_by_model = custom_attribute_columns_and_models.compact.group_by { |x| x[:model] }

    custom_attributes_group_by_model.each do |model, custom_attribute|
      model.load_custom_attributes_for(custom_attribute.map { |x| x[:column] })
    end
  end

  def self.proto?
    return @proto if defined?(@proto)
    @proto = ::Settings.product.proto
  end

  def self.to_human(exp)
    if exp.kind_of?(self)
      exp.to_human
    else
      if exp.kind_of?(Hash)
        case exp["mode"]
        when "tag_expr"
          return exp["expr"]
        when "tag"
          tag = [exp["ns"], exp["tag"]].join("/")
          if exp["include"] == "none"
            return "Not Tagged With #{tag}"
          else
            return "Tagged With #{tag}"
          end
        when "script"
          if exp["expr"] == "true"
            return "Always True"
          else
            return exp["expr"]
          end
        else
          return new(exp).to_human
        end
      else
        return exp.inspect
      end
    end
  end

  def to_human
    self.class._to_human(@exp)
  end

  def self._to_human(exp, options = {})
    return exp unless exp.kind_of?(Hash) || exp.kind_of?(Array)

    keys = exp.keys
    keys.delete(:token)
    operator = keys.first
    case operator.downcase
    when "like", "not like", "starts with", "ends with", "includes", "includes any", "includes all", "includes only", "limited to", "regular expression", "regular expression matches", "regular expression does not match", "equal", "=", "<", ">", ">=", "<=", "!=", "before", "after"
      operands = operands2humanvalue(exp[operator], options)
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "and", "or"
      clause = "( " + exp[operator].collect { |operand| _to_human(operand) }.join(" #{normalize_operator(operator)} ") + " )"
    when "not", "!"
      clause = normalize_operator(operator) + " ( " + _to_human(exp[operator]) + " )"
    when "is null", "is not null", "is empty", "is not empty"
      clause = operands2humanvalue(exp[operator], options).first + " " + operator
    when "contains"
      operands = operands2humanvalue(exp[operator], options)
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "find"
      # FIND Vm.users-name = 'Administrator' CHECKALL Vm.users-enabled = 1
      check = nil
      check = "checkall" if exp[operator].include?("checkall")
      check = "checkany" if exp[operator].include?("checkany")
      check = "checkcount" if exp[operator].include?("checkcount")
      raise _("expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'") unless check
      check =~ /^check(.*)$/; mode = $1.upcase
      clause = "FIND" + " " + _to_human(exp[operator]["search"]) + " CHECK " + mode + " " + _to_human(exp[operator][check], :include_table => false).strip
    when "key exists"
      clause = "KEY EXISTS #{exp[operator]['regkey']}"
    when "value exists"
      clause = "VALUE EXISTS #{exp[operator]['regkey']} : #{exp[operator]['regval']}"
    when "is"
      operands = operands2humanvalue(exp[operator], options)
      clause = "#{operands.first} #{operator} #{operands.last}"
    when "between dates", "between times"
      col_name = exp[operator]["field"]
      col_type = get_col_type(col_name)
      col_human, dumy = operands2humanvalue(exp[operator], options)
      vals_human = exp[operator]["value"].collect { |v| quote_human(v, col_type) }
      clause = "#{col_human} #{operator} #{vals_human.first} AND #{vals_human.last}"
    when "from"
      col_name = exp[operator]["field"]
      col_type = get_col_type(col_name)
      col_human, dumy = operands2humanvalue(exp[operator], options)
      vals_human = exp[operator]["value"].collect { |v| quote_human(v, col_type) }
      clause = "#{col_human} #{operator} #{vals_human.first} THROUGH #{vals_human.last}"
    end

    # puts "clause: #{clause}"
    clause
  end

  def to_ruby(tz = nil)
    tz ||= "UTC"
    @ruby ||= self.class._to_ruby(@exp.deep_clone, @context_type, tz)
    @ruby.dup
  end

  def self._to_ruby(exp, context_type, tz)
    return exp unless exp.kind_of?(Hash)

    operator = exp.keys.first
    case operator.downcase
    when "equal", "=", "<", ">", ">=", "<=", "!="
      col_type = get_col_type(exp[operator]["field"]) if exp[operator]["field"]
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "before"
      col_type = get_col_type(exp[operator]["field"]) if exp[operator]["field"]
      col_name = exp[operator]["field"]
      col_ruby, = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      val = exp[operator]["value"]
      clause = ruby_for_date_compare(col_ruby, col_type, tz, "<", val)
    when "after"
      col_type = get_col_type(exp[operator]["field"]) if exp[operator]["field"]
      col_name = exp[operator]["field"]
      col_ruby, = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      val = exp[operator]["value"]
      clause = ruby_for_date_compare(col_ruby, col_type, tz, nil, nil, ">", val)
    when "includes all"
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      clause = "(#{operands[0]} & #{operands[1]}) == #{operands[1]}"
    when "includes any"
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      clause = "(#{operands[1]} - #{operands[0]}) != #{operands[1]}"
    when "includes only", "limited to"
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      clause = "(#{operands[0]} - #{operands[1]}) == []"
    when "like", "not like", "starts with", "ends with", "includes"
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      case operator.downcase
      when "starts with"
        operands[1] = "/^" + re_escape(operands[1].to_s) + "/"
      when "ends with"
        operands[1] = "/" + re_escape(operands[1].to_s) + "$/"
      else
        operands[1] = "/" + re_escape(operands[1].to_s) + "/"
      end
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
      clause = "!(" + clause + ")" if operator.downcase == "not like"
    when "regular expression matches", "regular expression does not match"
      operands = operands2rubyvalue(operator, exp[operator], context_type)

      # If it looks like a regular expression, sanitize from forward
      # slashes and interpolation
      #
      # Regular expressions with a single option are also supported,
      # e.g. "/abc/i"
      #
      # Otherwise sanitize the whole string and add the delimiters
      #
      # TODO: support regexes with more than one option
      if operands[1].starts_with?("/") && operands[1].ends_with?("/")
        operands[1][1..-2] = sanitize_regular_expression(operands[1][1..-2])
      elsif operands[1].starts_with?("/") && operands[1][-2] == "/"
        operands[1][1..-3] = sanitize_regular_expression(operands[1][1..-3])
      else
        operands[1] = "/" + sanitize_regular_expression(operands[1].to_s) + "/"
      end
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "and", "or"
      clause = "(" + exp[operator].collect { |operand| _to_ruby(operand, context_type, tz) }.join(" #{normalize_ruby_operator(operator)} ") + ")"
    when "not", "!"
      clause = normalize_ruby_operator(operator) + "(" + _to_ruby(exp[operator], context_type, tz) + ")"
    when "is null", "is not null", "is empty", "is not empty"
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "contains"
      operands = operands2rubyvalue(operator, exp[operator], context_type)
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "find"
      # FIND Vm.users-name = 'Administrator' CHECKALL Vm.users-enabled = 1
      check = nil
      check = "checkall" if exp[operator].include?("checkall")
      check = "checkany" if exp[operator].include?("checkany")
      if exp[operator].include?("checkcount")
        check = "checkcount"
        op = exp[operator][check].keys.first
        exp[operator][check][op]["field"] = "<count>"
      end
      raise _("expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'") unless check
      check =~ /^check(.*)$/; mode = $1.downcase
      clause = "<find><search>" + _to_ruby(exp[operator]["search"], context_type, tz) + "</search><check mode=#{mode}>" + _to_ruby(exp[operator][check], context_type, tz) + "</check></find>"
    when "key exists"
      clause = operands2rubyvalue(operator, exp[operator], context_type)
    when "value exists"
      clause = operands2rubyvalue(operator, exp[operator], context_type)
    when "is"
      col_name = exp[operator]["field"]
      col_ruby, dummy = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      col_type = get_col_type(col_name)
      value = exp[operator]["value"]
      clause = if col_type == :date && !RelativeDatetime.relative?(value)
                 ruby_for_date_compare(col_ruby, col_type, tz, "==", value)
               else
                 ruby_for_date_compare(col_ruby, col_type, tz, ">=", value, "<=", value)
               end
    when "from"
      col_name = exp[operator]["field"]
      col_ruby, dummy = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      col_type = get_col_type(col_name)

      start_val, end_val = exp[operator]["value"]
      clause = ruby_for_date_compare(col_ruby, col_type, tz, ">=", start_val, "<=", end_val)
    else
      raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator}
    end

    # puts "clause: #{clause}"
    clause
  end

  def to_sql(tz = nil)
    tz ||= "UTC"
    @pexp, attrs = preprocess_for_sql(@exp.deep_clone)
    sql = to_arel(@pexp, tz).to_sql if @pexp.present?
    incl = includes_for_sql unless sql.blank?
    [sql, incl, attrs]
  end

  def preprocess_for_sql(exp, attrs = nil)
    attrs ||= {:supported_by_sql => true}
    operator = exp.keys.first
    case operator.downcase
    when "and"
      exp[operator].dup.each { |atom| preprocess_for_sql(atom, attrs) }
      exp[operator].reject!(&:blank?)
      exp.delete(operator) if exp[operator].empty?
    when "or"
      or_attrs = {:supported_by_sql => true}
      exp[operator].each { |atom| preprocess_for_sql(atom, or_attrs) }
      exp[operator].reject!(&:blank?)
      attrs.merge!(or_attrs)
      exp.delete(operator) if !or_attrs[:supported_by_sql] || exp[operator].empty? # Clean out unsupported or empty operands
    when "not", "!"
      preprocess_for_sql(exp[operator], attrs)
      exp.delete(operator) if exp[operator].empty? # Clean out empty operands
    else
      # check operands to see if they can be represented in sql
      unless sql_supports_atom?(exp)
        attrs[:supported_by_sql] = false
        exp.delete(operator)
      end
    end

    exp.empty? ? [nil, attrs] : [exp, attrs]
  end

  def sql_supports_atom?(exp)
    operator = exp.keys.first
    case operator.downcase
    when "contains"
      if exp[operator].keys.include?("tag") && exp[operator]["tag"].split(".").length == 2 # Only support for tags of the main model
        return true
      elsif exp[operator].keys.include?("field") && exp[operator]["field"].split(".").length == 2
        db, field = exp[operator]["field"].split(".")
        assoc, field = field.split("-")
        ref = db.constantize.reflect_on_association(assoc.to_sym)
        return false unless ref
        return false unless ref.macro == :has_many || ref.macro == :has_one
        return false if ref.options && ref.options.key?(:as)
        return field_in_sql?(exp[operator]["field"])
      else
        return false
      end
    when "includes"
      # Support includes operator using "LIKE" only if first operand is in main table
      if exp[operator].key?("field") && (!exp[operator]["field"].include?(".") || (exp[operator]["field"].include?(".") && exp[operator]["field"].split(".").length == 2))
        return field_in_sql?(exp[operator]["field"])
      else
        # TODO: Support includes operator for sub-sub-tables
        return false
      end
    when "find", "regular expression matches", "regular expression does not match", "key exists", "value exists"
      return false
    else
      # => false if operand is a tag
      return false if exp[operator].keys.include?("tag")

      # => false if operand is a registry
      return false if exp[operator].keys.include?("regkey")

      # => TODO: support count of child relationship
      return false if exp[operator].key?("count")

      return field_in_sql?(exp[operator]["field"]) && value_in_sql?(exp[operator]["value"])
    end
  end

  def value_in_sql?(value)
    !Field.is_field?(value) || Field.parse(value).attribute_supported_by_sql?
  end

  def field_in_sql?(field)
    # => false if operand is from a virtual reflection
    return false if self.field_from_virtual_reflection?(field)
    return false unless attribute_supported_by_sql?(field)

    # => false if excluded by special case defined in preprocess options
    return false if self.field_excluded_by_preprocess_options?(field)

    true
  end

  def field_from_virtual_reflection?(field)
    col_details[field][:virtual_reflection]
  end

  def attribute_supported_by_sql?(field)
    return false unless col_details[field]
    col_details[field][:sql_support]
  end

  def field_excluded_by_preprocess_options?(field)
    col_details[field][:excluded_by_preprocess_options]
  end

  def col_details
    @col_details ||= self.class.get_cols_from_expression(@exp, @preprocess_options)
  end

  def includes_for_sql
    col_details.values.each_with_object({}) { |v, result| result.deep_merge!(v[:include]) }
  end

  def self.expand_conditional_clause(klass, cond)
    return klass.send(:sanitize_sql_for_conditions, cond) unless cond.kind_of?(Hash)

    cond = klass.predicate_builder.resolve_column_aliases(cond)
    cond = klass.send(:expand_hash_conditions_for_aggregates, cond)

    klass.predicate_builder.build_from_hash(cond).map { |b|
      klass.connection.visitor.compile b
    }.join(' AND ')
  end

  def self.merge_where_clauses(*list)
    list = list.compact.collect do |s|
      expand_conditional_clause(MiqReport, s)
    end.compact

    if list.size == 0
      nil
    elsif list.size == 1
      list.first
    else
      "(#{list.join(") AND (")})"
    end
  end

  def self.merge_includes(*incl_list)
    return nil if incl_list.blank?
    incl_list.compact.each_with_object({}) { |i, result| result.deep_merge!(i) }
  end

  def self.get_cols_from_expression(exp, options = {})
    result = {}
    if exp.kind_of?(Hash)
      if exp.key?("field")
        result[exp["field"]] = get_col_info(exp["field"], options) unless exp["field"] == "<count>"
      elsif exp.key?("count")
        result[exp["count"]] = get_col_info(exp["count"], options)
      elsif exp.key?("tag")
        # ignore
      else
        exp.each_value { |v| result.merge!(get_cols_from_expression(v, options)) }
      end
    elsif exp.kind_of?(Array)
      exp.each { |v| result.merge!(get_cols_from_expression(v, options)) }
    end
    result
  end

  def self.get_col_info(field, options = {})
    result ||= {:data_type => nil, :virtual_reflection => false, :virtual_column => false, :sql_support => true, :excluded_by_preprocess_options => false, :tag => false, :include => {}}
    col = field.split("-").last if field.include?("-")
    parts = field.split("-").first.split(".")
    model = parts.shift

    if model.downcase == "managed" || parts.last == "managed"
      result[:data_type] = :string
      result[:tag] = true
      return result
    end
    model = model_class(model)
    cur_incl = result[:include]

    parts.each do |assoc|
      assoc = assoc.to_sym
      ref = model.reflection_with_virtual(assoc)
      result[:virtual_reflection] = true if model.virtual_reflection?(assoc)

      unless result[:virtual_reflection]
        cur_incl[assoc] ||= {}
        cur_incl = cur_incl[assoc]
      end

      unless ref
        result[:virtual_reflection] = true
        result[:sql_support] = false
        result[:virtual_column] = true
        return result
      end

      model = ref.klass
    end
    if col
      result[:data_type] = col_type(model, col)
      result[:format_sub_type] = MiqReport::FORMAT_DEFAULTS_AND_OVERRIDES[:sub_types_by_column][col.to_sym] || result[:data_type]
      result[:virtual_column] = model.virtual_attribute?(col.to_s)
      result[:sql_support] = model.attribute_supported_by_sql?(col.to_s)
      result[:excluded_by_preprocess_options] = self.exclude_col_by_preprocess_options?(col, options)
    end
    result
  end

  def self.exclude_col_by_preprocess_options?(col, options)
    return false unless options.kind_of?(Hash)
    return false unless options[:vim_performance_daily_adhoc]
    Metric::Rollup.excluded_col_for_expression?(col.to_sym)
  end

  def lenient_evaluate(obj, tz = nil)
    ruby_exp = to_ruby(tz)
    ruby_exp.nil? || Condition.subst_matches?(ruby_exp, obj)
  end

  def evaluate(obj, tz = nil)
    ruby_exp = to_ruby(tz)
    _log.debug("Expression before substitution: #{ruby_exp}")
    subst_expr = Condition.subst(ruby_exp, obj)
    _log.debug("Expression after substitution: #{subst_expr}")
    result = Condition.do_eval(subst_expr)
    _log.debug("Expression evaluation result: [#{result}]")
    result
  end

  def self.evaluate_atoms(exp, obj)
    exp = exp.kind_of?(self) ? copy_hash(exp.exp) : exp
    exp["result"] = new(exp).evaluate(obj)

    operators = exp.keys
    operators.each do|k|
      if ["and", "or"].include?(k.to_s.downcase)      # and/or atom is an array of atoms
        exp[k].each do|atom|
          evaluate_atoms(atom, obj)
        end
      elsif ["not", "!"].include?(k.to_s.downcase)    # not atom is a hash expression
        evaluate_atoms(exp[k], obj)
      else
        next
      end
    end
    exp
  end

  def self.operands2humanvalue(ops, options = {})
    # puts "Enter: operands2humanvalue: ops: #{ops.inspect}"
    ret = []
    if ops["tag"]
      v = nil
      ret.push(ops["alias"] || value2human(ops["tag"], options))
      MiqExpression.get_entry_details(ops["tag"]).each do|t|
        v = "'" + t.first + "'" if t.last == ops["value"]
      end
      if ops["value"] == :user_input
        v = "<user input>"
      else
        v ||= ops["value"].kind_of?(String) ? "'" + ops["value"] + "'" : ops["value"]
      end
      ret.push(v)
    elsif ops["field"]
      ops["value"] ||= ''
      if ops["field"] == "<count>"
        ret.push(nil)
        ret.push(ops["value"])
      else
        ret.push(ops["alias"] || value2human(ops["field"], options))
        if ops["value"] == :user_input
          ret.push("<user input>")
        else
          col_type = get_col_type(ops["field"]) || "string"
          ret.push(quote_human(ops["value"], col_type.to_s))
        end
      end
    elsif ops["count"]
      ret.push("COUNT OF " + (ops["alias"] || value2human(ops["count"], options)).strip)
      if ops["value"] == :user_input
        ret.push("<user input>")
      else
        ret.push(ops["value"])
      end
    elsif ops["regkey"]
      ops["value"] ||= ''
      ret.push(ops["regkey"] + " : " + ops["regval"])
      ret.push(ops["value"].kind_of?(String) ? "'" + ops["value"] + "'" : ops["value"])
    elsif ops["value"]
      ret.push(nil)
      ret.push(ops["value"])
    end
    ret
  end

  def self.value2human(val, options = {})
    options = {
      :include_model => true,
      :include_table => true
    }.merge(options)
    tables, col = val.split("-")
    first = true
    val_is_a_tag = false
    ret = ""
    if options[:include_table] == true
      friendly = tables.split(".").collect do|t|
        if t.downcase == "managed"
          val_is_a_tag = true
          "#{Tenant.root_tenant.name} Tags"
        elsif t.downcase == "user_tag"
          "My Tags"
        else
          if first
            first = nil
            next unless options[:include_model] == true
            Dictionary.gettext(t, :type => :model, :notfound => :titleize)
          else
            Dictionary.gettext(t, :type => :table, :notfound => :titleize)
          end
        end
      end.compact
      ret = friendly.join(".")
      ret << " : " unless ret.blank? || col.blank?
    end
    if val_is_a_tag
      if col
        classification = options[:classification] || Classification.find_by_name(col)
        ret << (classification ? classification.description : col)
      end
    else
      model = tables.blank? ? nil : tables.split(".").last.singularize.camelize
      dict_col = model.nil? ? col : [model, col].join(".")
      column_human = if col
                       if col.starts_with?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)
                         col.gsub(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX, "")
                       else
                         Dictionary.gettext(dict_col, :type => :column, :notfound => :titleize)
                       end
                     end
      ret << column_human if col
    end
    ret = " #{ret}" unless ret.include?(":")
    ret
  end

  def self.operands2rubyvalue(operator, ops, context_type)
    # puts "Enter: operands2rubyvalue: operator: #{operator}, ops: #{ops.inspect}"
    operator = operator.downcase
    ops["tag"] = ops["field"] if operator == "contains" && !ops["tag"] # process values in contains as tags

    if ops["tag"] && context_type != "hash"
      ref, val = value2tag(preprocess_managed_tag(ops["tag"]), ops["value"])
      [ref ? "<exist ref=#{ref}>#{val}</exist>" : "<exist>#{val}</exist>"]
    elsif ops["tag"] && context_type == "hash"
      # This is only for supporting reporting "display filters"
      # In the report object the tag value is actually the description and not the raw tag name.
      # So we have to trick it by replacing the value with the description.
      description = MiqExpression.get_entry_details(ops["tag"]).inject("") do|s, t|
        break(t.first) if t.last == ops["value"]
        s
      end
      val = ops["tag"].split(".").last.split("-").join(".")
      fld = "<value type=string>#{val}</value>"
      [fld, quote(description, "string")]
    elsif ops["field"]
      if ops["field"] == "<count>"
        ["<count>", quote(ops["value"], "integer")]
      else
        case context_type
        when "hash"
          ref = nil
          val = ops["field"].split(".").last.split("-").join(".")
        else
          ref, val = value2tag(ops["field"])
        end
        col_type = get_col_type(ops["field"]) || "string"
        fld = ref ? "<value ref=#{ref}, type=#{col_type}>#{val}</value>" : "<value type=#{col_type}>#{val}</value>"
        if ["like", "not like", "starts with", "ends with", "includes", "regular expression matches", "regular expression does not match"].include?(operator)
          [fld, ops["value"]]
        else
          [fld, quote(ops["value"], col_type.to_s)]
        end
      end
    elsif ops["count"]
      ref, count = value2tag(ops["count"])
      field = ref ? "<count ref=#{ref}>#{count}</count>" : "<count>#{count}</count>"
      [field, quote(ops["value"], "integer")]
    elsif ops["regkey"]
      if operator == "key exists"
        "<registry key_exists=1, type=boolean>#{ops["regkey"].strip}</registry>  == 'true'"
      elsif operator == "value exists"
        "<registry value_exists=1, type=boolean>#{ops["regkey"].strip} : #{ops["regval"]}</registry>  == 'true'"
      else
        fld = "<registry>#{ops["regkey"].strip} : #{ops["regval"]}</registry>"
        if ["like", "not like", "starts with", "ends with", "includes", "regular expression matches", "regular expression does not match"].include?(operator)
          [fld, ops["value"]]
        else
          [fld, quote(ops["value"], "string")]
        end
      end
    end
  end

  def self.quote(val, typ)
    if Field.is_field?(val)
      ref, value = value2tag(val)
      col_type = get_col_type(val) || "string"
      return ref ? "<value ref=#{ref}, type=#{col_type}>#{value}</value>" : "<value type=#{col_type}>#{value}</value>"
    end
    case typ.to_s
    when "string", "text", "boolean", nil
      # escape any embedded single quotes, etc. - needs to be able to handle even values with trailing backslash
      val.to_s.inspect
    when "date"
      return "nil" if val.blank? # treat nil value as empty string
      "\'#{val}\'.to_date"
    when "datetime"
      return "nil" if val.blank? # treat nil value as empty string
      "\'#{val.iso8601}\'.to_time(:utc)"
    when "integer", "decimal", "fixnum"
      val.to_s.to_i_with_method
    when "float"
      val.to_s.to_f_with_method
    when "numeric_set"
      val = val.split(",") if val.kind_of?(String)
      v_arr = val.to_miq_a.flat_map do |v|
        v = eval(v) rescue nil if v.kind_of?(String)
        v.kind_of?(Range) ? v.to_a : v
      end.compact.uniq.sort
      "[#{v_arr.join(",")}]"
    when "string_set"
      val = val.split(",") if val.kind_of?(String)
      v_arr = val.to_miq_a.flat_map { |v| "'#{v.to_s.strip}'" }.uniq.sort
      "[#{v_arr.join(",")}]"
    else
      val
    end
  end

  def self.quote_human(val, typ)
    case typ.to_s
    when "integer", "decimal", "fixnum", "float"
      return val.to_i unless val.to_s.number_with_method? || typ.to_s == "float"
      if val =~ /^([0-9\.,]+)\.([a-z]+)$/
        val = $1; sfx = $2
        if sfx.ends_with?("bytes") && FORMAT_BYTE_SUFFIXES.key?(sfx.to_sym)
          return "#{val} #{FORMAT_BYTE_SUFFIXES[sfx.to_sym]}"
        else
          return "#{val} #{sfx.titleize}"
        end
      else
        return val
      end
    when "string", "date", "datetime"
      return "\"#{val}\""
    else
      return quote(val, typ)
    end
  end

  # TODO: update this to use the more nuanced
  # .sanitize_regular_expression after performing Regexp.escape. The
  # extra substitution is required because, although the result from
  # Regexp.escape is fine to pass to Regexp.new, it is not when eval'd
  # as we do:
  #
  # ```ruby
  # regexp_string = Regexp.escape("/") # => "/"
  # # ...
  # eval("/" + regexp_string + "/")
  # ```
  def self.re_escape(s)
    Regexp.escape(s).gsub(/\//, '\/')
  end

  # Escape any unescaped forward slashes and/or interpolation
  def self.sanitize_regular_expression(string)
    string.gsub(%r{\\*/}, "\\/").gsub(/\\*#/, "\\\#")
  end

  def self.preprocess_managed_tag(tag)
    path, val = tag.split("-")
    path_arr = path.split(".")
    if path_arr.include?("managed") || path_arr.include?("user_tag")
      name = nil
      while path_arr.first != "managed" && path_arr.first != "user_tag"
        name = path_arr.shift
      end
      return [name].concat(path_arr).join(".") + "-" + val
    end
    tag
  end

  def self.value2tag(tag, val = nil)
    model, *values = tag.to_s.gsub(/[\.-]/, "/").split("/") # replace model path ".", column name "-" with "/"

    case values.first
    when "user_tag"
      values[0] = "user"
    when "managed", "user"
      # Keep as-is
    else
      values.unshift("virtual") # add in tag designation
    end

    unless val.nil?
      values << val.to_s.gsub(/\//, "%2f") # encode embedded / characters in values since / is used as a tag seperator
    end

    [model.downcase, "/#{values.join('/')}"]
  end

  def self.normalize_ruby_operator(str)
    str = str.upcase
    case str
    when "EQUAL", "="
      "=="
    when "NOT"
      "!"
    when "LIKE", "NOT LIKE", "STARTS WITH", "ENDS WITH", "INCLUDES", "REGULAR EXPRESSION MATCHES"
      "=~"
    when "REGULAR EXPRESSION DOES NOT MATCH"
      "!~"
    when "IS NULL", "IS EMPTY"
      "=="
    when "IS NOT NULL", "IS NOT EMPTY"
      "!="
    when "BEFORE"
      "<"
    when "AFTER"
      ">"
    else
      str.downcase
    end
  end

  def self.normalize_operator(str)
    str = str.upcase
    case str
    when "EQUAL"
      "="
    when "!"
      "NOT"
    when "EXIST"
      "CONTAINS"
    else
      str
    end
  end

  def self.base_tables
    BASE_TABLES
  end

  def self.model_details(model, opts = {:typ => "all", :include_model => true, :include_tags => false, :include_my_tags => false})
    @classifications = nil
    model = model.to_s

    opts = {:typ => "all", :include_model => true}.merge(opts)
    if opts[:typ] == "tag"
      tags_for_model = tag_details(model, model, opts)
      result = []
      TAG_CLASSES.invert.each do |name, tc|
        next if tc.constantize.base_class == model.constantize.base_class
        path = [model, name].join(".")
        result.concat(tag_details(tc, path, opts))
      end
      @classifications = nil
      return tags_for_model.concat(result.sort! { |a, b| a.to_s <=> b.to_s })
    end

    relats = get_relats(model)

    result = []
    unless opts[:typ] == "count" || opts[:typ] == "find"
      result = get_column_details(relats[:columns], model, model, opts).sort! { |a, b| a.to_s <=> b.to_s }

      unless opts[:disallow_loading_virtual_custom_attributes]
        custom_details = _custom_details_for(model, opts)
        result.concat(custom_details.sort_by(&:to_s)) unless custom_details.empty?
      end

      result.concat(tag_details(model, model, opts)) if opts[:include_tags] == true
    end

    model_details = _model_details(relats, opts)

    model_details.sort_by!(&:to_s)
    result.concat(model_details)

    @classifications = nil
    result
  end

  def self._custom_details_for(model, options)
    klass = model.safe_constantize
    return [] unless klass < CustomAttributeMixin

    custom_attributes_details = []

    klass.custom_keys.each do |custom_key|
      custom_detail_column = [model, CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX + custom_key].join("-")
      custom_detail_name = custom_key
      if options[:include_model]
        model_name = Dictionary.gettext(model, :type => :model, :notfound => :titleize)
        custom_detail_name = [model_name, custom_key].join(" : ")
      end
      custom_attributes_details.push([custom_detail_name, custom_detail_column])
    end

    custom_attributes_details
  end

  def self._model_details(relats, opts)
    result = []
    relats[:reflections].each do|_assoc, ref|
      parent = ref[:parent]
      case opts[:typ]
      when "count"
        result.push(get_table_details(parent[:class_path], parent[:assoc_path])) if parent[:multivalue]
      when "find"
        result.concat(get_column_details(ref[:columns], parent[:class_path], parent[:assoc_path], opts)) if parent[:multivalue]
      else
        result.concat(get_column_details(ref[:columns], parent[:class_path], parent[:assoc_path], opts))
        result.concat(tag_details(parent[:assoc_class], parent[:class_path], opts)) if opts[:include_tags] == true
      end

      result.concat(_model_details(ref, opts))
    end
    result
  end

  def self.tag_details(model, path, opts)
    return [] unless TAG_CLASSES.include?(model)
    result = []
    @classifications ||= get_categories
    @classifications.each do|name, cat|
      prefix = path.nil? ? "managed" : [path, "managed"].join(".")
      field = [prefix, name].join("-")
      result.push([value2human(field, opts.merge(:classification => cat)), field])
    end
    if opts[:include_my_tags] && opts[:userid] && ::Tag.exists?(["name like ?", "/user/#{opts[:userid]}/%"])
      prefix = path.nil? ? "user_tag" : [path, "user_tag"].join(".")
      field = [prefix, opts[:userid]].join("_")
      result.push([value2human(field, opts), field])
    end
    result.sort! { |a, b| a.to_s <=> b.to_s }
  end

  def self.get_relats(model)
    @model_relats ||= {}
    @model_relats[model] ||= build_relats(model)
  end

  def self.miq_adv_search_lists(model, what)
    @miq_adv_search_lists ||= {}
    @miq_adv_search_lists[model.to_s] ||= {}

    case what.to_sym
    when :exp_available_fields then
      options = {:typ => "field", :include_model => true, :disallow_loading_virtual_custom_attributes => false}
      @miq_adv_search_lists[model.to_s][:exp_available_fields] ||= MiqExpression.model_details(model, options)
    when :exp_available_counts then @miq_adv_search_lists[model.to_s][:exp_available_counts] ||= MiqExpression.model_details(model, :typ => "count", :include_model => true)
    when :exp_available_finds  then @miq_adv_search_lists[model.to_s][:exp_available_finds]  ||= MiqExpression.model_details(model, :typ => "find",  :include_model => true)
    end
  end

  def self.reporting_available_fields(model, interval = nil)
    @reporting_available_fields ||= {}
    if model.to_s == "VimPerformanceTrend"
      @reporting_available_fields[model.to_s] ||= {}
      @reporting_available_fields[model.to_s][interval.to_s] ||= VimPerformanceTrend.trend_model_details(interval.to_s)
    elsif model.ends_with?("Performance")
      @reporting_available_fields[model.to_s] ||= {}
      @reporting_available_fields[model.to_s][interval.to_s] ||= MiqExpression.model_details(model, :include_model => false, :include_tags => true, :interval => interval)
    elsif Chargeback.db_is_chargeback?(model)
      cb_model = Chargeback.report_cb_model(model)
      @reporting_available_fields[model.to_s] ||=
        MiqExpression.model_details(model, :include_model => false, :include_tags => true).select { |c| c.last.ends_with?(*ReportController::Reports::Editor::CHARGEBACK_ALLOWED_FIELD_SUFFIXES) } +
        MiqExpression.tag_details(cb_model, model, {}) + _custom_details_for(cb_model, {})
    else
      @reporting_available_fields[model.to_s] ||= MiqExpression.model_details(model, :include_model => false, :include_tags => true)
    end
  end

  def self.build_relats(model, parent = {}, seen = [])
    _log.info("Building relationship tree for: [#{parent[:path]} => #{model}]...")

    model = model_class(model)

    parent[:class_path] ||= model.name
    parent[:assoc_path] ||= model.name
    parent[:root] ||= model.name
    result = {:columns => model.attribute_names, :parent => parent}
    result[:reflections] = {}

    refs = model.reflections_with_virtual
    if model.try(:include_descendant_classes_in_expressions?)
      model.descendants.each { |desc| refs.reverse_merge!(desc.reflections_with_virtual) }
    end

    refs.each do |assoc, ref|
      next unless INCLUDE_TABLES.include?(assoc.to_s.pluralize)
      next if     assoc.to_s.pluralize == "event_logs" && parent[:root] == "Host" && !proto?
      next if     assoc.to_s.pluralize == "processes" && parent[:root] == "Host" # Process data not available yet for Host

      next if ref.macro == :belongs_to && model.name != parent[:root]

      # REMOVE ME: workaround to temporarily exlude certain mdoels from the relationships
      excluded_models = EXCLUDE_FROM_RELATS[model.name]
      next if excluded_models && excluded_models.include?(assoc.to_s)

      assoc_class = ref.klass.name

      new_parent = {
        :macro       => ref.macro,
        :class_path  => [parent[:class_path], determine_relat_path(ref)].join("."),
        :assoc_path  => [parent[:assoc_path], assoc.to_s].join("."),
        :assoc       => assoc,
        :assoc_class => assoc_class,
        :root        => parent[:root]
      }
      new_parent[:direction] = new_parent[:macro] == :belongs_to ? :up : :down
      new_parent[:multivalue] = [:has_many, :has_and_belongs_to_many].include?(new_parent[:macro])

      seen_key = [model.name, assoc].join("_")
      unless seen.include?(seen_key) ||
             assoc_class == parent[:root] ||
             parent[:assoc_path].include?(assoc.to_s) ||
             parent[:assoc_path].include?(assoc.to_s.singularize) ||
             parent[:direction] == :up ||
             parent[:multivalue]
        seen.push(seen_key)
        result[:reflections][assoc] = build_relats(assoc_class, new_parent, seen)
      end
    end
    result
  end

  def self.get_table_details(class_path, assoc_path)
    [value2human(class_path), assoc_path]
  end

  def self.get_column_details(column_names, class_path, assoc_path, opts)
    include_model = opts[:include_model]
    base_model = class_path.split(".").first

    excludes =  EXCLUDE_COLUMNS
    # special case for C&U ad-hoc reporting
    if opts[:interval] && opts[:interval] != "daily" && base_model.ends_with?("Performance") && !class_path.include?(".")
      excludes += ["^min_.*$", "^max_.*$", "^.*derived_storage_.*$", "created_on"]
    elsif opts[:interval] && base_model.ends_with?("Performance") && !class_path.include?(".")
      excludes += ["created_on"]
    end

    excludes += ["logical_cpus"] if class_path == "Vm.hardware"

    case base_model
    when "VmPerformance"
      excludes += ["^.*derived_host_count_off$", "^.*derived_host_count_on$", "^.*derived_vm_count_off$", "^.*derived_vm_count_on$", "^.*derived_storage.*$"]
    when "HostPerformance"
      excludes += ["^.*derived_host_count_off$", "^.*derived_host_count_on$", "^.*derived_storage.*$", "^abs_.*$"]
    when "EmsClusterPerformance"
      excludes += ["^.*derived_storage.*$", "sys_uptime_absolute_latest", "^abs_.*$"]
    when "StoragePerformance"
      includes = ["^.*derived_storage.*$", "^timestamp$", "v_date", "v_time", "resource_name"]
      column_names = column_names.collect do |c|
        next(c) if includes.include?(c)
        c if includes.detect { |incl| c.match(incl) }
      end.compact
    end

    column_names.collect do|c|
      # check for direct match first
      next if excludes.include?(c) && !EXCLUDE_EXCEPTIONS.include?(c)

      # check for regexp match if no direct match
      col = c
      excludes.each do|excl|
        if c.match(excl)
          col = nil
          break
        end
      end unless EXCLUDE_EXCEPTIONS.include?(c)
      if col
        field_class_path = "#{class_path}-#{col}"
        field_assoc_path = "#{assoc_path}-#{col}"
        [value2human(field_class_path, :include_model => include_model), field_assoc_path]
      end
    end.compact
  end

  def self.get_col_type(field)
    model, parts, col = parse_field(field)

    return :string if model.downcase == "managed" || parts.last == "managed"
    return nil unless field.include?("-")

    model = determine_model(model, parts)
    return nil if model.nil?
    return Field.parse(field).column_type if col.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)

    col_type(model, col)
  end

  def self.col_type(model, col)
    model = model_class(model)
    model.type_for_attribute(col).type
  end

  def self.parse_field(field)
    col = field.split("-").last
    col = col.split("__").first unless col.nil? # throw away pivot table suffix if it exists before looking up type

    parts = field.split("-").first.split(".")
    model = parts.shift

    return model, parts, col
  end

  NUM_OPERATORS     = ["=", "!=", "<", "<=", ">=", ">"].freeze
  STRING_OPERATORS  = ["=",
                       "STARTS WITH",
                       "ENDS WITH",
                       "INCLUDES",
                       "IS NULL",
                       "IS NOT NULL",
                       "IS EMPTY",
                       "IS NOT EMPTY",
                       "REGULAR EXPRESSION MATCHES",
                       "REGULAR EXPRESSION DOES NOT MATCH"]
  SET_OPERATORS     = ["INCLUDES ALL",
                       "INCLUDES ANY",
                       "LIMITED TO"]
  REGKEY_OPERATORS  = ["KEY EXISTS",
                       "VALUE EXISTS"]
  BOOLEAN_OPERATORS = ["=",
                       "IS NULL",
                       "IS NOT NULL"]
  DATE_TIME_OPERATORS       = ["IS", "BEFORE", "AFTER", "FROM", "IS EMPTY", "IS NOT EMPTY"]

  def self.get_col_operators(field)
    if field == :count || field == :regkey
      col_type = field
    else
      col_type = get_col_type(field.to_s) || :string
    end

    case col_type.to_s.downcase.to_sym
    when :string
      return STRING_OPERATORS
    when :integer, :float, :fixnum, :count
      return NUM_OPERATORS
    when :numeric_set, :string_set
      return SET_OPERATORS
    when :regkey
      return STRING_OPERATORS + REGKEY_OPERATORS
    when :boolean
      return BOOLEAN_OPERATORS
    when :date, :datetime
      return DATE_TIME_OPERATORS
    else
      return STRING_OPERATORS
    end
  end

  STYLE_OPERATORS_EXCLUDES = ["REGULAR EXPRESSION MATCHES", "REGULAR EXPRESSION DOES NOT MATCH", "FROM"].freeze
  def self.get_col_style_operators(field)
    result = get_col_operators(field) - STYLE_OPERATORS_EXCLUDES
  end

  def self.get_entry_details(field)
    ns = field.split("-").first.split(".").last

    if ns == "managed"
      cat = field.split("-").last
      catobj = Classification.find_by_name(cat)
      return catobj ? catobj.entries.collect { |e| [e.description, e.name] } : []
    elsif ns == "user_tag" || ns == "user"
      cat = field.split("-").last
      return ::Tag.where("name like ?", "/user/#{cat}%").select(:name).collect do |t|
        tag_name = t.name.split("/").last
        [tag_name, tag_name]
      end
    else
      return field
    end
  end

  def self.atom_error(field, operator, value)
    return false if operator == "DEFAULT" # No validation needed for style DEFAULT operator

    value = value.to_s unless value.kind_of?(Array)

    dt = case operator.to_s.downcase
         when "regular expression matches", "regular expression does not match" # TODO
           :regexp
         else
           if field == :count
             :integer
           else
             col_info = get_col_info(field)
             [:bytes, :megabytes].include?(col_info[:format_sub_type]) ? :integer : col_info[:data_type]
           end
         end

    case dt
    when :string, :text
      return false
    when :integer, :fixnum, :decimal, :float
      return false if send((dt == :float ? :is_numeric? : :is_integer?), value)

      dt_human = dt == :float ? "Number" : "Integer"
      return _("%{value_name} value must not be blank") % {:value_name => dt_human} if value.delete(',').blank?

      if value.include?(".") && (value.split(".").last =~ /([a-z]+)/i)
        sfx = $1
        sfx = sfx.ends_with?("bytes") && FORMAT_BYTE_SUFFIXES.key?(sfx.to_sym) ? FORMAT_BYTE_SUFFIXES[sfx.to_sym] : sfx.titleize
        value = "#{value.split(".")[0..-2].join(".")} #{sfx}"
      end

      return _("Value '%{value}' is not a valid %{value_name}") % {:value => value, :value_name => dt_human}
    when :date, :datetime
      return false if operator.downcase.include?("empty")

      values = value.to_miq_a
      return _("No Date/Time value specified") if values.empty? || values.include?(nil)
      return _("Two Date/Time values must be specified") if operator.downcase == "from" && values.length < 2

      values_converted = values.collect do |v|
        return _("Date/Time value must not be blank") if value.blank?
        v_cvt = RelativeDatetime.normalize(v, "UTC") rescue nil
        return _("Value '%{value}' is not valid") % {:value => v} if v_cvt.nil?
        v_cvt
      end
      if values_converted.length > 1 && values_converted[0] > values_converted[1]
        return _("Invalid Date/Time range, %{first_value} comes before %{second_value}") % {:first_value  => values[1],
                                                                                            :second_value => values[0]}
      end
      return false
    when :boolean
      unless operator.downcase.include?("null") || %w(true false).include?(value)
        return _("Value must be true or false")
      end
      return false
    when :regexp
      begin
        Regexp.new(value).match("foo")
      rescue => err
        return _("Regular expression '%{value}' is invalid, '%{error_message}'") % {:value         => value,
                                                                                    :error_message => err.message}
      end
      return false
    else
      return false
    end

    _("Value '%{value}' must be in the form of %{format_type}") % {:value       => value,
                                                                   :format_type => FORMAT_SUB_TYPES[dt][:short_name]}
  end

  def self.get_categories
    classifications = Classification.in_my_region.hash_all_by_type_and_name(:show => true)
    categories_with_entries = classifications.reject { |_k, v| !v.key?(:entry) }
    categories_with_entries.each_with_object({}) do |(name, hash), categories|
      categories[name] = hash[:category]
    end
  end

  def self.model_class(model)
    # TODO: the temporary cache should be removed after widget refactoring
    @@model_class ||= Hash.new { |h, m| h[m] = m.kind_of?(Class) ? m : m.to_s.singularize.camelize.constantize rescue nil }
    @@model_class[model]
  end

  def self.is_integer?(n)
    n = n.to_s
    n2 = n.delete(',') # strip out commas
    begin
      Integer n2
      return true
    rescue
      return false unless n.number_with_method?
      begin
        n2 = n.to_f_with_method
        return (n2.to_i == n2)
      rescue
        return false
      end
    end
  end

  def self.is_numeric?(n)
    n = n.to_s
    n2 = n.delete(',') # strip out commas
    begin
      Float n2
      return true
    rescue
      return false unless n.number_with_method?
      begin
        n.to_f_with_method
        return true
      rescue
        return false
      end
    end
  end

  # Is an MiqExpression or an expression hash a quick_search
  def self.quick_search?(exp)
    return exp.quick_search? if exp.kind_of?(self)
    self._quick_search?(exp)
  end

  def quick_search?
    self.class._quick_search?(exp)  # Pass the exp hash
  end

  # Is an expression hash a quick search?
  def self._quick_search?(e)
    case e
    when Array
      e.any? { |e_exp| _quick_search?(e_exp) }
    when Hash
      return true if e["value"] == :user_input
      e.values.any? { |e_exp| _quick_search?(e_exp) }
    else
      false
    end
  end

  def custom_attribute_columns_and_models(expression = nil)
    return custom_attribute_columns_and_models(exp).uniq if expression.nil?

    case expression
    when Array
      expression.flat_map { |x| custom_attribute_columns_and_models(x) }
    when Hash
      expression_values = expression.values
      return [] unless expression.keys.first

      if expression.keys.first == "field"
        begin
          field = Field.parse(expression_values.first)
        rescue StandardError => err
          _log.error("Cannot parse field #{field}" + err.message)
          _log.log_backtrace(err)
        end

        return [] unless field

        field.custom_attribute_column? ? [:model => field.model, :column => field.column] : []
      else
        expression.keys.first.casecmp('find').try(:zero?) ? [] : custom_attribute_columns_and_models(expression_values)
      end
    else
      []
    end
  end


  private

  # example:
  #   ruby_for_date_compare(:updated_at, :date, tz, "==", Time.now)
  #   # => "val=update_at; !val.nil? && val.to_date == '2016-10-05'"
  #
  #   ruby_for_date_compare(:updated_at, :time, tz, ">", Time.yesterday, "<", Time.now)
  #   # => "val=update_at; !val.nil? && val.utc > '2016-10-04T13:08:00-04:00' && val.utc < '2016-10-05T13:08:00-04:00'"

  def self.ruby_for_date_compare(col_ruby, col_type, tz, op1, val1, op2 = nil, val2 = nil)
    val_with_cast = "val.#{col_type == :date ? "to_date" : "to_time"}"
    val1 = RelativeDatetime.normalize(val1, tz, "beginning", col_type == :date) if val1
    val2 = RelativeDatetime.normalize(val2, tz, "end",       col_type == :date) if val2
    [
      "val=#{col_ruby}; !val.nil?",
      op1 ? "#{val_with_cast} #{op1} #{quote(val1, col_type)}" : nil,
      op2 ? "#{val_with_cast} #{op2} #{quote(val2, col_type)}" : nil,
    ].compact.join(" && ")
  end

  def to_arel(exp, tz)
    operator = exp.keys.first
    field = Field.parse(exp[operator]["field"]) if exp[operator].kind_of?(Hash) && exp[operator]["field"]
    if(exp[operator].kind_of?(Hash) && exp[operator]["value"] && Field.is_field?(exp[operator]["value"]))
      parsed_value = Field.parse(exp[operator]["value"]).arel_attribute
    elsif exp[operator].kind_of?(Hash)
      parsed_value = exp[operator]["value"]
    end
    case operator.downcase
    when "equal", "="
      field.eq(parsed_value)
    when ">"
      field.gt(parsed_value)
    when "after"
      value = RelativeDatetime.normalize(parsed_value, tz, "end", field.date?)
      field.gt(value)
    when ">="
      field.gteq(parsed_value)
    when "<"
      field.lt(parsed_value)
    when "before"
      value = RelativeDatetime.normalize(parsed_value, tz, "beginning", field.date?)
      field.lt(value)
    when "<="
      field.lteq(parsed_value)
    when "!="
      field.not_eq(parsed_value)
    when "like", "includes"
      field.matches("%#{parsed_value}%")
    when "starts with"
      field.matches("#{parsed_value}%")
    when "ends with"
      field.matches("%#{parsed_value}")
    when "not like"
      field.does_not_match("%#{parsed_value}%")
    when "and"
      operands = exp[operator].each_with_object([]) do |operand, result|
        next if operand.blank?
        arel = to_arel(operand, tz)
        next if arel.blank?
        result << arel
      end
      Arel::Nodes::And.new(operands)
    when "or"
      operands = exp[operator].each_with_object([]) do |operand, result|
        next if operand.blank?
        arel = to_arel(operand, tz)
        next if arel.blank?
        result << arel
      end
      first, *rest = operands
      rest.inject(first) { |lhs, rhs| lhs.or(rhs) }
    when "not", "!"
      Arel::Nodes::Not.new(to_arel(exp[operator], tz))
    when "is null"
      field.eq(nil)
    when "is not null"
      field.not_eq(nil)
    when "is empty"
      arel = field.eq(nil)
      arel = arel.or(field.eq("")) if field.string?
      arel
    when "is not empty"
      arel = field.not_eq(nil)
      arel = arel.and(field.not_eq("")) if field.string?
      arel
    when "contains"
      # Only support for tags of the main model
      if exp[operator].key?("tag")
        tag = Tag.parse(exp[operator]["tag"])
        tag.contains(parsed_value)
      else
        field.contains(parsed_value)
      end
    when "is"
      value = parsed_value
      start_val = RelativeDatetime.normalize(value, tz, "beginning", field.date?)
      end_val = RelativeDatetime.normalize(value, tz, "end", field.date?)

      if !field.date? || RelativeDatetime.relative?(value)
        field.between(start_val..end_val)
      else
        field.eq(start_val)
      end
    when "from"
      start_val, end_val = parsed_value
      start_val = RelativeDatetime.normalize(start_val, tz, "beginning", field.date?)
      end_val   = RelativeDatetime.normalize(end_val, tz, "end", field.date?)
      field.between(start_val..end_val)
    else
      raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator}
    end
  end

  def self.determine_model(model, parts)
    model = model_class(model)
    return nil if model.nil?

    parts.each do |assoc|
      ref = model.reflection_with_virtual(assoc.to_sym)
      return nil if ref.nil?
      model = ref.klass
    end

    model
  end

  def self.determine_relat_path(ref)
    last_path = ref.name.to_s
    class_from_association_name = model_class(last_path)
    return last_path unless class_from_association_name

    association_class = ref.klass
    if association_class < class_from_association_name
      last_path = ref.collection? ? association_class.model_name.plural : association_class.model_name.singular
    end
    last_path
  end
end # class MiqExpression
