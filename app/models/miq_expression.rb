class MiqExpression
  include Vmdb::Logging
  attr_accessor :exp, :context_type, :preprocess_options

  BASE_TABLES = %w(
    AuditEvent
    AvailabilityZone
    BottleneckEvent
    Chargeback
    CloudResourceQuota
    CloudTenant
    Compliance
    ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem
    ManageIQ::Providers::ConfigurationManager
    Container
    ContainerGroup
    ContainerImages
    ContainerNode
    ContainerProject
    ContainerService
    ContainerReplicator
    ManageIQ::Providers::CloudManager
    EmsCluster
    EmsClusterPerformance
    EmsEvent
    ManageIQ::Providers::InfraManager
    ExtManagementSystem
    ExtManagementSystemPerformance
    Flavor
    Host
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
    Repository
    ResourcePool
    SecurityGroup
    Service
    ServiceTemplate
    Storage
    StorageFile
    StoragePerformance
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
    hardwares
    hosts
    host_services
    kernel_drivers
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
    repositories
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

    disk_io_cost
    disk_io_metric
    net_io_cost
    net_io_metric
    fixed_2_cost
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
    'ExtManagementSystem'                         => 'ext_management_system',
    'Host'                                        => 'host',
    'MiqGroup'                                    => 'miq_group',
    'MiqTemplate'                                 => 'miq_template',
    'Repository'                                  => 'repository',
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
    :ruby        => {
      :short_name => _("Ruby Script"),
      :title      => _("Enter one or more lines of Ruby Script")
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

  def initialize(expr, ctype = nil)
    @exp = expr
    @context_type = ctype
  end

  def self.proto?
    return @proto if defined?(@proto)
    @proto = VMDB::Config.new("vmdb").config.fetch_path(:product, :proto)
  end

  def self.to_human(expr)
    if expr.kind_of?(self)
      expr.to_human
    else
      if expr.kind_of?(Hash)
        case expr["mode"]
        when "tag_expr"
          return expr["expr"]
        when "tag"
          tag = [expr["ns"], expr["tag"]].join("/")
          if expr["include"] == "none"
            return "Not Tagged With #{tag}"
          else
            return "Tagged With #{tag}"
          end
        when "script"
          if expr["expr"] == "true"
            return "Always True"
          else
            return expr["expr"]
          end
        else
          return new(expr).to_human
        end
      else
        return expr.inspect
      end
    end
  end

  def to_human
    self.class._to_human(@exp)
  end

  def self._to_human(expr, options = {})
    return expr unless expr.kind_of?(Hash) || expr.kind_of?(Array)

    keys = expr.keys
    keys.delete(:token)
    operator = keys.first
    case operator.downcase
    when "like", "not like", "starts with", "ends with", "includes", "includes any", "includes all", "includes only", "limited to", "regular expression", "regular expression matches", "regular expression does not match", "equal", "=", "<", ">", ">=", "<=", "!=", "before", "after"
      operands = operands2humanvalue(expr[operator], options)
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "and", "or"
      clause = "( " + expr[operator].collect { |operand| _to_human(operand) }.join(" #{normalize_operator(operator)} ") + " )"
    when "not", "!"
      clause = normalize_operator(operator) + " ( " + _to_human(expr[operator]) + " )"
    when "is null", "is not null", "is empty", "is not empty"
      clause = operands2humanvalue(expr[operator], options).first + " " + operator
    when "contains"
      operands = operands2humanvalue(expr[operator], options)
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "find"
      # FIND Vm.users-name = 'Administrator' CHECKALL Vm.users-enabled = 1
      check = nil
      check = "checkall" if expr[operator].include?("checkall")
      check = "checkany" if expr[operator].include?("checkany")
      check = "checkcount" if expr[operator].include?("checkcount")
      raise _("expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'") unless check
      check =~ /^check(.*)$/; mode = $1.upcase
      clause = "FIND" + " " + _to_human(expr[operator]["search"]) + " CHECK " + mode + " " + _to_human(expr[operator][check], :include_table => false).strip
    when "key exists"
      clause = "KEY EXISTS #{expr[operator]['regkey']}"
    when "value exists"
      clause = "VALUE EXISTS #{expr[operator]['regkey']} : #{expr[operator]['regval']}"
    when "ruby"
      operands = operands2humanvalue(expr[operator], options)
      operands[1] = "<RUBY Expression>"
      clause = operands.join(" #{normalize_operator(operator)} \n")
    when "is"
      operands = operands2humanvalue(expr[operator], options)
      clause = "#{operands.first} #{operator} #{operands.last}"
    when "between dates", "between times"
      col_name = expr[operator]["field"]
      col_type = get_col_type(col_name)
      col_human, dumy = operands2humanvalue(expr[operator], options)
      vals_human = expr[operator]["value"].collect { |v| quote_human(v, col_type) }
      clause = "#{col_human} #{operator} #{vals_human.first} AND #{vals_human.last}"
    when "from"
      col_name = expr[operator]["field"]
      col_type = get_col_type(col_name)
      col_human, dumy = operands2humanvalue(expr[operator], options)
      vals_human = expr[operator]["value"].collect { |v| quote_human(v, col_type) }
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

  def self._to_ruby(expr, cont_type, tz)
    return expr unless expr.kind_of?(Hash) || expr.kind_of?(Array)

    operator = expr.keys.first
    case operator.downcase
    when "equal", "=", "<", ">", ">=", "<=", "!=", "before", "after"
      col_type = get_col_type(expr[operator]["field"]) if expr[operator]["field"]
      return _to_ruby({"date_time_with_logical_operator" => expr}, cont_type, tz) if col_type == :date || col_type == :datetime

      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "includes all"
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      clause = "(#{operands[0]} & #{operands[1]}) == #{operands[1]}"
    when "includes any"
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      clause = "(#{operands[1]} - #{operands[0]}) != #{operands[1]}"
    when "includes only", "limited to"
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      clause = "(#{operands[0]} - #{operands[1]}) == []"
    when "like", "not like", "starts with", "ends with", "includes"
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
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
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      operands[1] = "/" + operands[1].to_s + "/" unless operands[1].starts_with?("/") && (operands[1].ends_with?("/") || operands[1][-2..-2] == "/")
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "and", "or"
      clause = "(" + expr[operator].collect { |operand| _to_ruby(operand, cont_type, tz) }.join(" #{normalize_ruby_operator(operator)} ") + ")"
    when "not", "!"
      clause = normalize_ruby_operator(operator) + "(" + _to_ruby(expr[operator], cont_type, tz) + ")"
    when "is null", "is not null", "is empty", "is not empty"
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "contains"
      operands = operands2rubyvalue(operator, expr[operator], cont_type)
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "find"
      # FIND Vm.users-name = 'Administrator' CHECKALL Vm.users-enabled = 1
      check = nil
      check = "checkall" if expr[operator].include?("checkall")
      check = "checkany" if expr[operator].include?("checkany")
      if expr[operator].include?("checkcount")
        check = "checkcount"
        op = expr[operator][check].keys.first
        expr[operator][check][op]["field"] = "<count>"
      end
      raise _("expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'") unless check
      check =~ /^check(.*)$/; mode = $1.downcase
      clause = "<find><search>" + _to_ruby(expr[operator]["search"], cont_type, tz) + "</search><check mode=#{mode}>" + _to_ruby(expr[operator][check], cont_type, tz) + "</check></find>"
    when "key exists"
      clause = operands2rubyvalue(operator, expr[operator], cont_type)
    when "value exists"
      clause = operands2rubyvalue(operator, expr[operator], cont_type)
    when "ruby"
      raise _("Ruby scripts in expressions are no longer supported. Please use the regular expression feature of conditions instead.")
    when "is"
      col_name = expr[operator]["field"]
      col_ruby, dummy = operands2rubyvalue(operator, {"field" => col_name}, cont_type)
      col_type = get_col_type(col_name)
      value = expr[operator]["value"]
      if col_type == :date
        if self.date_time_value_is_relative?(value)
          start_val = quote(normalize_date_time(value, "UTC", "beginning").to_date, :date)
          end_val   = quote(normalize_date_time(value, "UTC", "end").to_date, :date)
          clause    = "val=#{col_ruby}; !val.nil? && val.to_date >= #{start_val} && val.to_date <= #{end_val}"
        else
          value  = quote(normalize_date_time(value, "UTC", "beginning").to_date, :date)
          clause = "val=#{col_ruby}; !val.nil? && val.to_date == #{value}"
        end
      else
        start_val = quote(normalize_date_time(value, tz, "beginning").utc, :datetime)
        end_val   = quote(normalize_date_time(value, tz, "end").utc, :datetime)
        clause    = "val=#{col_ruby}; !val.nil? && val.to_time >= #{start_val} && val.to_time <= #{end_val}"
      end
    when "from"
      col_name = expr[operator]["field"]
      col_ruby, dummy = operands2rubyvalue(operator, {"field" => col_name}, cont_type)
      col_type = get_col_type(col_name)

      start_val, end_val = expr[operator]["value"]
      if col_type == :date
        start_val = quote(normalize_date_time(start_val, "UTC", "beginning").to_date, :date)
        end_val   = quote(normalize_date_time(end_val, "UTC", "end").to_date, :date)

        clause = "val=#{col_ruby}; !val.nil? && val.to_date >= #{start_val} && val.to_date <= #{end_val}"
      else
        start_val = quote(normalize_date_time(start_val, tz, "beginning").utc, :datetime)
        end_val   = quote(normalize_date_time(end_val, tz, "end").utc, :datetime)

        clause = "val=#{col_ruby}; !val.nil? && val.to_time >= #{start_val} && val.to_time <= #{end_val}"
      end
    when "date_time_with_logical_operator"
      expr = expr[operator]
      operator = expr.keys.first

      col_name = expr[operator]["field"]
      col_type = get_col_type(col_name)
      col_ruby, dummy = operands2rubyvalue(operator, {"field" => col_name}, cont_type)

      normalized_operator = normalize_ruby_operator(operator)
      mode = case normalized_operator
             when ">", "<="  then "end"        # (>  <date> 23::59:59), (<= <date> 23::59:59)
             when "<", ">="  then "beginning"  # (<  <date> 00::00:00), (>= <date> 00::00:00)
             end

      if col_type == :date
        val = normalize_date_time(expr[operator]["value"], "UTC", mode)

        clause = "val=#{col_ruby}; !val.nil? && val.to_date #{normalized_operator} #{quote(val.to_date, :date)}"
      else
        val = normalize_date_time(expr[operator]["value"], tz, mode)

        clause = "val=#{col_ruby}; !val.nil? && val.to_time #{normalized_operator} #{quote(val.utc, :datetime)}"
      end
    else
      raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator}
    end

    # puts "clause: #{clause}"
    clause
  end

  def self.normalize_date_time(rel_time, tz, mode = "beginning")
    # time_spec =
    #   <value> <interval> Ago
    #   "Today"
    #   "Yesterday"
    #   "Now"
    #   "Last Week"
    #   "Last Month"
    #   "Last Quarter"
    #   "This Week"
    #   "This Month"
    #   "This Quarter"

    rt = rel_time.downcase

    if rt.starts_with?("this", "last")
      # Convert these into the time spec form: <value> <interval> Ago
      value, interval = rt.split
      rt = "#{value == "this" ? 0 : 1} #{interval} ago"
    end

    if rt.ends_with?("ago")
      # Time spec <value> <interval> Ago
      value, interval, ago = rt.split
      interval = interval.pluralize

      if interval == "hours"
        beginning_or_end_of_hour(value.to_i.hours.ago.in_time_zone(tz), mode)
      elsif interval == "quarters"
        ts = Time.now.in_time_zone(tz).beginning_of_quarter
        (ts - (value.to_i * 3.months)).send("#{mode}_of_quarter")
      else
        value.to_i.send(interval).ago.in_time_zone(tz).send("#{mode}_of_#{interval.singularize}")
      end
    elsif rt == "today"
      Time.now.in_time_zone(tz).send("#{mode}_of_day")
    elsif rt == "yesterday"
      1.day.ago.in_time_zone(tz).send("#{mode}_of_day")
    elsif rt == "now"
      beginning_or_end_of_hour(Time.now.in_time_zone(tz), mode)
    else
      # Assume it's an absolute date or time
      value_is_date = !rel_time.include?(":")
      ts = Time.use_zone(tz) { Time.zone.parse(rel_time) }
      ts = ts.send("#{mode}_of_day") if mode && value_is_date
      ts
    end
  end

  def self.beginning_or_end_of_hour(ts, mode)
    ts_str = ts.iso8601
    ts_str[14..18] = mode == "end" ? "59:59" : "00:00"
    Time.parse(ts_str)
  end

  def self.date_time_value_is_relative?(value)
    v = value.downcase
    v.starts_with?("this", "last") || v.ends_with?("ago") || ["today", "yesterday", "now"].include?(v)
  end

  def to_sql(tz = nil)
    tz ||= "UTC"
    @pexp, attrs = preprocess_for_sql(@exp.deep_clone)
    sql = _to_sql(@pexp, tz) if @pexp.present?
    incl = includes_for_sql unless sql.blank?
    [sql, incl, attrs]
  end

  def _to_sql(expr, tz)
    operator = expr.keys.first

    case operator.downcase
    when "equal", "="
      field = Field.parse(expr[operator]["field"])
      return _to_sql({"date_time_with_logical_operator" => expr}, tz) if field.date? || field.datetime?
      table = Arel::Table.new(field.table_name)
      clause = table[field.column].eq(Arel::Nodes::Quoted.new(expr[operator]["value"])).to_sql
    when "<", ">", ">=", "<=", "!=", "before", "after"
      col_type = self.class.get_col_type(expr[operator]["field"]) if expr[operator]["field"]
      return _to_sql({"date_time_with_logical_operator" => expr}, tz) if col_type == :date || col_type == :datetime

      operands = self.class.operands2sqlvalue(operator, expr[operator])
      clause = operands.join(" #{self.class.normalize_sql_operator(operator)} ")
    when "like", "not like", "starts with", "ends with", "includes"
      operands = self.class.operands2sqlvalue(operator, expr[operator])
      case operator.downcase
      when "starts with"
        operands[1] = "'" + operands[1].to_s + "%'"
      when "ends with"
        operands[1] = "'%" + operands[1].to_s + "'"
      when "like", "not like", "includes"
        operands[1] = "'%" + operands[1].to_s + "%'"
      end
      clause = operands.join(" #{self.class.normalize_sql_operator(operator)} ")
      clause = "!(" + clause + ")" if operator.downcase == "not like"
    when "and", "or"
      operands = expr[operator].collect do|operand|
        o = _to_sql(operand, tz) if operand.present?
        o.blank? ? nil : o
      end.compact
      if operands.length > 1
        clause = "(" + operands.join(" #{self.class.normalize_sql_operator(operator)} ") + ")"
      elsif operands.length == 1 # Operands may have been stripped out during pre-processing
        clause = "(" + operands.first + ")"
      end
    when "not", "!"
      clause = self.class.normalize_sql_operator(operator) + " " + _to_sql(expr[operator], tz)
    when "is null", "is not null"
      operands = self.class.operands2sqlvalue(operator, expr[operator])
      clause = "(#{operands[0]} #{self.class.normalize_sql_operator(operator)})"
    when "is empty", "is not empty"
      col      = expr[operator]["field"]
      col_type = col_details[col].nil? ? :string : col_details[col][:data_type]
      operands = self.class.operands2sqlvalue(operator, expr[operator])
      clause   = "(#{operands[0]} #{operator.sub(/empty/i, "NULL")})"
      if col_type == :string
        conjunction = (operator.downcase == 'is empty') ? 'OR' : 'AND'
        clause = "(#{clause} #{conjunction} (#{operands[0]} #{self.class.normalize_sql_operator(operator)} ''))"
      end
    when "contains"
      # Only support for tags of the main model
      if expr[operator].key?("tag")
        klass, ns = expr[operator]["tag"].split(".")
        ns  = "/" + ns.split("-").join("/")
        ns = ns.sub(/(\/user_tag\/)/, "/user/") # replace with correct namespace for user tags
        tag = expr[operator]["value"]
        klass = klass.constantize
        ids = klass.find_tagged_with(:any => tag, :ns => ns).pluck(:id)
        clause = klass.send(:sanitize_sql_for_conditions, ["#{klass.table_name}.id IN (?)", ids])
      else
        db, field = expr[operator]["field"].split(".")
        model = db.constantize
        assoc, field = field.split("-")
        ref = model.reflect_on_association(assoc.to_sym)

        inner_where = "#{field} = '#{expr[operator]["value"]}'"
        if cond = ref.scope          # Include ref.options[:conditions] in inner select if exists
          cond = extract_where_values(ref.klass, cond)
          inner_where = "(#{inner_where}) AND (#{cond})"
        end
        clause = "#{model.table_name}.id IN (SELECT DISTINCT #{ref.foreign_key} FROM #{ref.table_name} WHERE #{inner_where})"
      end
    when "is"
      col_name = expr[operator]["field"]
      col_sql, dummy = self.class.operands2sqlvalue(operator, "field" => col_name)
      col_type = self.class.get_col_type(col_name)
      value = expr[operator]["value"]
      if col_type == :date
        if self.class.date_time_value_is_relative?(value)
          start_val = self.class.quote(self.class.normalize_date_time(value, "UTC", "beginning").to_date, :date, :sql)
          end_val   = self.class.quote(self.class.normalize_date_time(value, "UTC", "end").to_date, :date, :sql)
          clause = "#{col_sql} BETWEEN #{start_val} AND #{end_val}"
        else
          value  = self.class.quote(self.class.normalize_date_time(value, "UTC", "beginning").to_date, :date, :sql)
          clause = "#{col_sql} = #{value}"
        end
      else
        start_val = self.class.quote(self.class.normalize_date_time(value, tz, "beginning").utc, :datetime, :sql)
        end_val   = self.class.quote(self.class.normalize_date_time(value, tz, "end").utc, :datetime, :sql)
        clause = "#{col_sql} BETWEEN #{start_val} AND #{end_val}"
      end
    when "from"
      col_name = expr[operator]["field"]
      col_sql, dummy = self.class.operands2sqlvalue(operator, "field" => col_name)
      col_type = self.class.get_col_type(col_name)

      start_val, end_val = expr[operator]["value"]
      if col_type == :date
        start_val = self.class.quote(self.class.normalize_date_time(start_val, "UTC", "beginning").to_date, :date, :sql)
        end_val   = self.class.quote(self.class.normalize_date_time(end_val, "UTC", "end").to_date, :date, :sql)

        clause = "#{col_sql} BETWEEN #{start_val} AND #{end_val}"
      else
        start_val = self.class.quote(self.class.normalize_date_time(start_val, tz, "beginning").utc, :datetime, :sql)
        end_val   = self.class.quote(self.class.normalize_date_time(end_val, tz, "end").utc, :datetime, :sql)

        clause = "#{col_sql} BETWEEN #{start_val} AND #{end_val}"
      end
    when "date_time_with_logical_operator"
      expr = expr[operator]
      operator = expr.keys.first

      col_name = expr[operator]["field"]
      col_type = self.class.get_col_type(col_name)
      col_sql, dummy = self.class.operands2sqlvalue(operator, "field" => col_name)

      normalized_operator = self.class.normalize_sql_operator(operator)
      mode = case normalized_operator
             when ">", "<="  then "end"        # (>  <date> 23::59:59), (<= <date> 23::59:59)
             when "<", ">="  then "beginning"  # (<  <date> 00::00:00), (>= <date> 00::00:00)
             end

      if col_type == :date
        val = self.class.normalize_date_time(expr[operator]["value"], "UTC", mode)

        clause = "#{col_sql} #{normalized_operator} #{self.class.quote(val.to_date, :date, :sql)}"
      else
        val = self.class.normalize_date_time(expr[operator]["value"], tz, mode)

        clause = "#{col_sql} #{normalized_operator} #{self.class.quote(val.utc, :datetime, :sql)}"
      end
    else
      raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator}
    end

    # puts "clause: #{clause}"
    clause
  end

  def preprocess_for_sql(expr, attrs = nil)
    attrs ||= {:supported_by_sql => true}
    operator = expr.keys.first
    case operator.downcase
    when "and"
      expr[operator].dup.each { |atom| preprocess_for_sql(atom, attrs) }
      expr[operator] = expr[operator].collect { |o| o.blank? ? nil : o }.compact # Clean out empty operands
      expr.delete(operator) if expr[operator].empty?
    when "or"
      or_attrs = {:supported_by_sql => true}
      expr[operator].each_with_index do |atom, i|
        preprocess_for_sql(atom, or_attrs)
        expr[operator][i] = nil if atom.blank?
      end
      expr[operator].compact!
      attrs.merge!(or_attrs)
      expr.delete(operator) if !or_attrs[:supported_by_sql] || expr[operator].empty? # Clean out unsupported or empty operands
    when "not", "!"
      preprocess_for_sql(expr[operator], attrs)
      expr.delete(operator) if expr[operator].empty? # Clean out empty operands
    else
      # check operands to see if they can be represented in sql
      unless sql_supports_atom?(expr)
        attrs[:supported_by_sql] = false
        expr.delete(operator)
      end
    end

    expr.empty? ? [nil, attrs] : [expr, attrs]
  end

  def sql_supports_atom?(expr)
    operator = expr.keys.first
    case operator.downcase
    when "contains"
      if expr[operator].keys.include?("tag") && expr[operator]["tag"].split(".").length == 2 # Only support for tags of the main model
        return true
      elsif expr[operator].keys.include?("field") && expr[operator]["field"].split(".").length == 2
        db, field = expr[operator]["field"].split(".")
        assoc, field = field.split("-")
        ref = db.constantize.reflect_on_association(assoc.to_sym)
        return false unless ref
        return false unless ref.macro == :has_many || ref.macro == :has_one
        return false if ref.options && ref.options.key?(:as)
        return field_in_sql?(expr[operator]["field"])
      else
        return false
      end
    when "includes"
      # Support includes operator using "LIKE" only if first operand is in main table
      if expr[operator].key?("field") && (!expr[operator]["field"].include?(".") || (expr[operator]["field"].include?(".") && expr[operator]["field"].split(".").length == 2))
        return field_in_sql?(expr[operator]["field"])
      else
        # TODO: Support includes operator for sub-sub-tables
        return false
      end
    when "find", "regular expression matches", "regular expression does not match", "key exists", "value exists", "ruby"
      return false
    else
      # => false if operand is a tag
      return false if expr[operator].keys.include?("tag")

      # => TODO: support count of child relationship
      return false if expr[operator].key?("count")

      return field_in_sql?(expr[operator]["field"])
    end
  end

  def field_in_sql?(field)
    # => false if operand is from a virtual reflection
    return false if self.field_from_virtual_reflection?(field)

    # => false if operand if a virtual coulmn
    return false if self.field_is_virtual_column?(field)

    # => false if excluded by special case defined in preprocess options
    return false if self.field_excluded_by_preprocess_options?(field)

    true
  end

  def field_from_virtual_reflection?(field)
    col_details[field][:virtual_reflection]
  end

  def field_is_virtual_column?(field)
    col_details[field][:virtual_column]
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

  def columns_for_sql(expr = nil, result = nil)
    expr ||= self.exp
    result ||= []
    return result unless expr.kind_of?(Hash)

    operator = expr.keys.first
    if expr[operator].kind_of?(Hash) && expr[operator].key?("field")
      unless expr[operator]["field"] == "<count>" || self.field_from_virtual_reflection?(expr[operator]["field"]) || self.field_is_virtual_column?(expr[operator]["field"])
        col = expr[operator]["field"]
        if col.include?(".")
          col = col.split(".").last
          col = col.sub("-", ".")
        else
          col = col.split("-").last
        end
        result << col
      end
    else
      expr[operator].dup.to_miq_a.each { |atom| columns_for_sql(atom, result) }
    end

    result.compact.uniq
  end

  def self.merge_where_clauses_and_includes(where_clauses, includes)
    [merge_where_clauses(*where_clauses), merge_includes(*includes)]
  end

  def self.expand_conditional_clause(klass, cond)
    return klass.send(:sanitize_sql_for_conditions, cond) unless cond.is_a?(Hash)

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

  def self.get_cols_from_expression(expr, options = {})
    result = {}
    if expr.kind_of?(Hash)
      if expr.key?("field")
        result[expr["field"]] = get_col_info(expr["field"], options) unless expr["field"] == "<count>"
      elsif expr.key?("count")
        result[expr["count"]] = get_col_info(expr["count"], options)
      elsif expr.key?("tag")
        # ignore
      else
        expr.each_value { |v| result.merge!(get_cols_from_expression(v, options)) }
      end
    elsif expr.kind_of?(Array)
      expr.each { |v| result.merge!(get_cols_from_expression(v, options)) }
    end
    result
  end

  def self.get_col_info(field, options = {})
    result ||= {:data_type => nil, :virtual_reflection => false, :virtual_column => false, :excluded_by_preprocess_options => false, :tag => false, :include => {}}
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
        result[:virtual_column] = true
        return result
      end

      model = ref.klass
    end
    if col
      result[:data_type] = col_type(model, col)
      result[:format_sub_type] = MiqReport::FORMAT_DEFAULTS_AND_OVERRIDES[:sub_types_by_column][col.to_sym] || result[:data_type]
      result[:virtual_column] = true if model.virtual_attribute?(col.to_s)
      result[:excluded_by_preprocess_options] = self.exclude_col_by_preprocess_options?(col, options)
    end
    result
  end

  def self.exclude_col_by_preprocess_options?(col, options)
    return false unless options.kind_of?(Hash)
    return false unless options[:vim_performance_daily_adhoc]
    Metric::Rollup.excluded_col_for_expression?(col.to_sym)
  end

  def self.evaluate(expression, obj, inputs = {}, tz = nil)
    ruby_exp = expression.kind_of?(Hash) ? new(expression).to_ruby(tz) : expression.to_ruby(tz)
    _log.debug("Expression before substitution: #{ruby_exp}")
    subst_expr = subst(ruby_exp, obj, inputs)
    _log.debug("Expression after substitution: #{subst_expr}")
    result = eval(subst_expr) ? true : false
    _log.debug("Expression evaluation result: [#{result}]")
    result
  end

  def evaluate(obj, inputs = {}, tz = nil)
    self.class.evaluate(self, obj, inputs, tz)
  end

  def self.evaluate_atoms(expr, obj, inputs = {})
    expr = expr.kind_of?(self) ? copy_hash(expr.exp) : expr
    expr["result"] = evaluate(expr, obj, inputs)

    operators = expr.keys
    operators.each do|k|
      if ["and", "or"].include?(k.to_s.downcase)      # and/or atom is an array of atoms
        expr[k].each do|atom|
          evaluate_atoms(atom, obj, inputs)
        end
      elsif ["not", "!"].include?(k.to_s.downcase)    # not atom is a hash expression
        evaluate_atoms(expr[k], obj, inputs)
      else
        next
      end
    end
    expr
  end

  def self.subst(ruby_exp, obj, inputs)
    Condition.subst(ruby_exp, obj, inputs)
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
      ret << Dictionary.gettext(dict_col, :type => :column, :notfound => :titleize) if col
    end
    ret = " #{ret}" unless ret.include?(":")
    ret
  end

  def self.operands2sqlvalue(operator, ops)
    # puts "Enter: operands2rubyvalue: operator: #{operator}, ops: #{ops.inspect}"
    operator = operator.downcase

    ret = []
    if  ops["field"]
      ret << get_sqltable(ops["field"].split("-").first) + "." + ops["field"].split("-").last
      col_type = get_col_type(ops["field"]) || "string"
      if ["like", "not like", "starts with", "ends with", "includes"].include?(operator)
        ret.push(ops["value"])
      else
        ret.push(quote(ops["value"], col_type.to_s, :sql))
      end
    elsif ops["count"]
      val = get_sqltable(ops["count"].split("-").first) + "." + ops["count"].split("-").last
      ret << "count(#{val})" # TODO
      ret.push(ops["value"])
    else
      return nil
    end
    ret
  end

  def self.operands2rubyvalue(operator, ops, cont_type)
    # puts "Enter: operands2rubyvalue: operator: #{operator}, ops: #{ops.inspect}"
    operator = operator.downcase
    ops["tag"] = ops["field"] if operator == "contains" && !ops["tag"] # process values in contains as tags

    ret = []
    if ops["tag"] && cont_type != "hash"
      ref, val = value2tag(preprocess_managed_tag(ops["tag"]), ops["value"])
      fld = val
      ret.push(ref ? "<exist ref=#{ref}>#{val}</exist>" : "<exist>#{val}</exist>")
    elsif ops["tag"] && cont_type == "hash"
      # This is only for supporting reporting "display filters"
      # In the report object the tag value is actually the description and not the raw tag name.
      # So we have to trick it by replacing the value with the description.
      description = MiqExpression.get_entry_details(ops["tag"]).inject("") do|s, t|
        break(t.first) if t.last == ops["value"]
        s
      end

      val = ops["tag"].split(".").last.split("-").join(".")
      fld = "<value type=string>#{val}</value>"
      ret.push(fld)
      ret.push(quote(description, "string"))
    elsif ops["field"]
      if ops["field"] == "<count>"
        ret.push("<count>")
        ret.push(ops["value"])
      else
        case cont_type
        when "hash"
          ref = nil
          val = ops["field"].split(".").last.split("-").join(".")
        else
          ref, val = value2tag(ops["field"])
        end
        col_type = get_col_type(ops["field"]) || "string"
        col_type = "raw" if operator == "ruby"
        fld = val
        fld = ref ? "<value ref=#{ref}, type=#{col_type}>#{val}</value>" : "<value type=#{col_type}>#{val}</value>"
        ret.push(fld)
        if ["like", "not like", "starts with", "ends with", "includes", "regular expression matches", "regular expression does not match", "ruby"].include?(operator)
          ret.push(ops["value"])
        else
          ret.push(quote(ops["value"], col_type.to_s))
        end
      end
    elsif ops["count"]
      ref, count = value2tag(ops["count"])
      ret.push(ref ? "<count ref=#{ref}>#{count}</count>" : "<count>#{count}</count>")
      ret.push(ops["value"])
    elsif ops["regkey"]
      ret.push("<registry>#{ops["regkey"].strip} : #{ops["regval"]}</registry>")
      if ["like", "not like", "starts with", "ends with", "includes", "regular expression matches", "regular expression does not match"].include?(operator)
        ret.push(ops["value"])
      elsif operator == "key exists"
        ret = "<registry key_exists=1, type=boolean>#{ops["regkey"].strip}</registry>  == 'true'"
      elsif operator == "value exists"
        ret = "<registry value_exists=1, type=boolean>#{ops["regkey"].strip} : #{ops["regval"]}</registry>  == 'true'"
      else
        ret.push(quote(ops["value"], "string"))
      end
    end
    ret
  end

  def self.quote(val, typ, mode = :ruby)
    case typ.to_s
    when "string", "text", "boolean", nil
      val = "" if val.nil? # treat nil value as empty string
      # escape any embedded single quotes, etc. - needs to be able to handle even values with trailing backslash
      return mode == :sql ? ActiveRecord::Base.connection.quote(val) : val.to_s.inspect
    when "date"
      return "nil" if val.blank? # treat nil value as empty string
      return mode == :sql ? ActiveRecord::Base.connection.quote(val) : "\'#{val}\'.to_date"
    when "datetime"
      return "nil" if val.blank? # treat nil value as empty string
      return mode == :sql ? ActiveRecord::Base.connection.quote(val.iso8601) : "\'#{val.iso8601}\'.to_time(:utc)"
    when "integer", "decimal", "fixnum"
      return val.to_s.to_i_with_method
    when "float"
      return val.to_s.to_f_with_method
    when "numeric_set"
      val = val.split(",") if val.kind_of?(String)
      v_arr = val.to_miq_a.collect do |v|
        v = eval(v) rescue nil if v.kind_of?(String)
        v.kind_of?(Range) ? v.to_a : v
      end.flatten.compact.uniq.sort
      return "[#{v_arr.join(",")}]"
    when "string_set"
      val = val.split(",") if val.kind_of?(String)
      v_arr = val.to_miq_a.collect { |v| "'#{v.to_s.strip}'" }.flatten.uniq.sort
      return "[#{v_arr.join(",")}]"
    when "raw"
      return val
    else
      return val
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

  def self.re_escape(s)
    Regexp.escape(s).gsub(/\//, '\/')
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

  def self.normalize_sql_operator(str)
    str = str.upcase
    case str
    when "EQUAL"
      "="
    when "!"
      "NOT"
    when "EXIST"
      "CONTAINS"
    when "LIKE", "NOT LIKE", "STARTS WITH", "ENDS WITH", "INCLUDES"
      "LIKE"
    when "IS EMPTY"
      "="
    when "IS NOT EMPTY"
      "!="
    when "BEFORE"
      "<"
    when "AFTER"
      ">"
    else
      str
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

  def self.get_sqltable(path)
    # puts "Enter: get_sqltable: path: #{path}"
    parts = path.split(".")
    name  = parts.last
    klass = parts.shift.constantize
    parts.reverse_each do |assoc|
      ref = klass.reflect_on_association(assoc.to_sym)
      if ref.nil?
        klass = nil
        break
      end
      klass = ref.class_name.constantize
    end

    klass ? klass.table_name : name.pluralize.underscore
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
      result.concat(tag_details(model, model, opts)) if opts[:include_tags] == true
    end
    result.concat(_model_details(relats, opts).sort! { |a, b| a.to_s <=> b.to_s })
    @classifications = nil
    result
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
    if opts[:include_my_tags] && opts[:userid] && Tag.exists?(["name like ?", "/user/#{opts[:userid]}/%"])
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

  def self.build_lists(model)
    _log.info("Building lists for: [#{model}]...")

    # Build expression lists
    [:exp_available_fields, :exp_available_counts, :exp_available_finds].each { |what| miq_adv_search_lists(model, what) }

    # Build reporting lists
    reporting_available_fields(model) unless model == model.ends_with?("Trend", "Performance") # Can't do trend/perf models at startup
  end

  def self.miq_adv_search_lists(model, what)
    @miq_adv_search_lists ||= {}
    @miq_adv_search_lists[model.to_s] ||= {}

    case what.to_sym
    when :exp_available_fields then @miq_adv_search_lists[model.to_s][:exp_available_fields] ||= MiqExpression.model_details(model, :typ => "field", :include_model => true)
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
    elsif model.to_s == "Chargeback"
      @reporting_available_fields[model.to_s] ||= MiqExpression.model_details(model, :include_model => false, :include_tags => true).select { |c| c.last.ends_with?("_cost", "_metric", "-owner_name") }
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

  NUM_OPERATORS     = ["=", "!=", "<", "<=", ">=", ">", "RUBY"]
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
    when :integer, :float, :fixnum
      return NUM_OPERATORS
    when :count
      return NUM_OPERATORS - ["RUBY"]
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

  STYLE_OPERATORS_EXCLUDES = ["RUBY", "REGULAR EXPRESSION MATCHES", "REGULAR EXPRESSION DOES NOT MATCH", "FROM"]
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
      return Tag.where("name like ?", "/user/#{cat}%").select(:name).collect do |t|
        tag_name = t.name.split("/").last
        [tag_name, tag_name]
      end
    else
      return field
    end
  end

  def self.is_plural?(field)
    parts = field.split("-").first.split(".")
    macro = nil
    model = model_class(parts.shift)
    parts.each do |assoc|
      ref = model.reflection_with_virtual(assoc.to_sym)
      return false if ref.nil?

      macro = ref.macro
      model = ref.klass
    end
    [:has_many, :has_and_belongs_to_many].include?(macro)
  end

  def self.atom_error(field, operator, value)
    return false if operator == "DEFAULT" # No validation needed for style DEFAULT operator

    value = value.to_s unless value.kind_of?(Array)

    dt = case operator.to_s.downcase
         when "ruby" # TODO
           :ruby
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
        v_cvt = normalize_date_time(v, "UTC") rescue nil
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
    when :ruby
      return _("Ruby Script must not be blank") if value.blank?
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
  def self.quick_search?(expr)
    return expr.quick_search? if expr.kind_of?(self)
    self._quick_search?(expr)
  end

  def quick_search?
    self.class._quick_search?(exp)  # Pass the exp hash
  end

  # Is an expression hash a quick search?
  def self._quick_search?(e)
    if e.kind_of?(Array)
      e.each { |e_exp| return true if self._quick_search?(e_exp) }
    elsif e.kind_of?(Hash)
      return true if e["value"] == :user_input
      e.each_value { |e_exp| return true if self._quick_search?(e_exp) }
    end
    false
  end

  private

  class WhereExtractionVisitor < Arel::Visitors::PostgreSQL
    def visit_Arel_Nodes_SelectStatement(o, collector)
      collector = o.cores.inject(collector) do |c, x|
        visit_Arel_Nodes_SelectCore(x, c)
      end
    end

    def visit_Arel_Nodes_SelectCore(o, collector)
      unless o.wheres.empty?
        len = o.wheres.length - 1
        o.wheres.each_with_index do |x, i|
          collector = visit(x, collector)
          collector << AND unless len == i
        end
      end

      collector
    end
  end

  def extract_where_values(klass, scope)
    relation = ActiveRecord::Relation.new klass, klass.arel_table, klass.predicate_builder
    relation = relation.instance_eval(&scope)

    begin
      # This is basically ActiveRecord::Relation#to_sql, only using our
      # custom visitor instance

      connection = klass.connection
      visitor    = WhereExtractionVisitor.new connection

      arel  = relation.arel
      binds = relation.bound_attributes
      binds = connection.prepare_binds_for_database(binds)
      binds.map! { |value| connection.quote(value) }
      collect = visitor.accept(arel.ast, Arel::Collectors::Bind.new)
      collect.substitute_binds(binds).join
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
