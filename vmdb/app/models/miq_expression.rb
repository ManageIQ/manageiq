class MiqExpression
  attr_accessor :exp, :context_type, :preprocess_options

  @@proto = VMDB::Config.new("vmdb").config[:product][:proto]
  @@base_tables = %w{
    AuditEvent
    BottleneckEvent
    Chargeback
    Compliance
    EmsCluster
    EmsClusterPerformance
    EmsEvent
    ExtManagementSystem
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
    PolicyEvent
    Repository
    ResourcePool
    Service
    ServiceTemplate
    Storage
    StorageFile
    StoragePerformance
    TemplateCloud
    TemplateInfra
    User
    VimPerformanceTrend
    Vm
    VmCloud
    VmInfra
    VmPerformance
    Zone
  }

  if VdiFarm.is_available?
    @@base_tables += %w{
      VdiController
      VdiDesktop
      VdiDesktopPool
      VdiEndpointDevice
      VdiFarm
      VdiSession
      VdiUser
      VmVdi
    }
  end

  @@include_tables = %w{
    advanced_settings
    audit_events
    compliances
    compliance_details
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
    service_templates
    services
    snapshots
    storages
    storage_adapters
    storage_files
    switches
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
  }

  if VdiFarm.is_available?
    @@include_tables += %w{
      vdi_controllers
      vdi_desktop_pools
      vdi_desktops
      vdi_endpoint_devices
      vdi_farms
      vdi_sessions
      vdi_users
    }

    @@include_tables += %w{ldaps} if VdiFarm::MGMT_ENABLED == true
  end

  EXCLUDE_COLUMNS = %w{
    ^.*_id$
    ^blackbox_.*$
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
  }

  EXCLUDE_EXCEPTIONS = %w{
    capacity_profile_1_memory_per_vm_with_min_max
    capacity_profile_1_vcpu_per_vm_with_min_max
    capacity_profile_2_memory_per_vm_with_min_max
    capacity_profile_2_vcpu_per_vm_with_min_max
    chain_id
    guid
  }

  TAG_CLASSES = [
    "EmsCloud", "ext_management_system",
    "EmsCluster", "ems_cluster",
    "EmsInfra", "ext_management_system",
    "Host", "host",
    "MiqGroup", "miq_group",
    "MiqTemplate", "miq_template",
    "Repository", "repository",
    "ResourcePool", "resource_pool",
    "Service", "service",
    "Storage", "storage",
    "TemplateCloud", "miq_template",
    "TemplateInfra", "miq_template",
    "User", "user",
    "Vm", "vm",
    "VmCloud", "vm",
    "VmInfra", "vm"
  ]

  FORMAT_SUB_TYPES = {
    :boolean => {
      :short_name => "Boolean",
      :title => "Enter true or false"
    },
    :bytes => {
      :short_name => "Bytes",
      :title => "Enter the number of Bytes",
      :units => [
        ["Bytes", :bytes],
        ["KB", :kilobytes],
        ["MB", :megabytes],
        ["GB", :gigabytes],
        ["TB", :terabytes]
      ]
    },
    :date => {
      :short_name => "Date",
      :title => "Click to Choose a Date"
    },
    :datetime => {
      :short_name => "Date / Time",
      :title => "Click to Choose a Date / Time"
    },
    :float => {
      :short_name => "Number",
      :title => "Enter a Number (like 12.56)"
    },
    :gigabytes => {
      :short_name => "Gigabytes",
      :title => "Enter the number of Gigabytes"
    },
    :integer => {
      :short_name => "Integer",
      :title => "Enter an Integer"
    },
    :kbps => {
      :short_name => "KBps",
      :title => "Enter the Kilobytes per second"
    },
    :kilobytes => {
      :short_name => "Kilobytes",
      :title => "Enter the number of Kilobytes"
    },
    :megabytes => {
      :short_name => "Megabytes",
      :title => "Enter the number of Megabytes"
    },
    :mhz => {
      :short_name => "Mhz",
      :title => "Enter the number of Megahertz"
    },
    :numeric_set => {
      :short_name => "Number List",
      :title => "Enter a list of numbers separated by commas"
    },
    :percent => {
      :short_name => "Percent",
      :title => "Enter a Percent (like 12.5)",
    },
    :regex => {
      :short_name => "Regular Expression",
      :title => "Enter a Regular Expression"
    },
    :ruby => {
      :short_name => "Ruby Script",
      :title => "Enter one or more lines of Ruby Script"
    },
    :string => {
      :short_name => "Text String",
      :title => "Enter a Text String"
    },
    :string_set  => {
      :short_name => "String List",
      :title => "Enter a list of text strings separated by commas"
    }
  }
  FORMAT_SUB_TYPES[:fixnum] = FORMAT_SUB_TYPES[:decimal] = FORMAT_SUB_TYPES[:integer]
  FORMAT_SUB_TYPES[:mhz_avg] = FORMAT_SUB_TYPES[:mhz]
  FORMAT_SUB_TYPES[:text] = FORMAT_SUB_TYPES[:string]
  FORMAT_BYTE_SUFFIXES = FORMAT_SUB_TYPES[:bytes][:units].inject({}) {|h, (v,k)| h[k] = v; h}

  def initialize(exp, ctype = nil)
    @exp = exp
    @context_type = ctype
  end

  def self.to_human(exp)
    if exp.is_a?(self)
      exp.to_human
    else
      if exp.is_a?(Hash)
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
          return self.new(exp).to_human
        end
      else
        return exp.inspect
      end
    end
  end

  def to_human
    self.class._to_human(@exp)
  end

  def self._to_human(exp, options={})
    return exp unless exp.is_a?(Hash) || exp.is_a?(Array)

    keys = exp.keys
    keys.delete(:token)
    operator = keys.first
    case operator.downcase
    when "like", "not like", "starts with", "ends with", "includes", "includes any", "includes all", "includes only", "limited to", "regular expression", "regular expression matches", "regular expression does not match", "equal", "=", "<", ">", ">=", "<=", "!=", "before", "after"
      operands = self.operands2humanvalue(exp[operator], options)
      clause = operands.join(" #{self.normalize_operator(operator)} ")
    when "and", "or"
      clause = "( " + exp[operator].collect {|operand| self._to_human(operand)}.join(" #{self.normalize_operator(operator)} ") + " )"
    when "not", "!"
      clause = self.normalize_operator(operator) + " ( " + self._to_human(exp[operator]) + " )"
    when "is null", "is not null", "is empty", "is not empty"
      clause = self.operands2humanvalue(exp[operator], options).first + " " + operator
    when "contains"
      operands = self.operands2humanvalue(exp[operator], options)
      clause = operands.join(" #{self.normalize_operator(operator)} ")
    when "find"
      # FIND Vm.users-name = 'Administrator' CHECKALL Vm.users-enabled = 1
      check = nil
      check = "checkall" if exp[operator].include?("checkall")
      check = "checkany" if exp[operator].include?("checkany")
      check = "checkcount" if exp[operator].include?("checkcount")
      raise "expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'" unless check
      check =~ /^check(.*)$/; mode = $1.upcase
      clause = "FIND" + " " + self._to_human(exp[operator]["search"])  + " CHECK " + mode + " " + self._to_human(exp[operator][check], :include_table => false).strip
    when "key exists"
      clause = "KEY EXISTS #{exp[operator]['regkey']}"
    when "value exists"
      clause = "VALUE EXISTS #{exp[operator]['regkey']} : #{exp[operator]['regval']}"
    when "ruby"
      operands = self.operands2humanvalue(exp[operator], options)
      operands[1] = "<RUBY Expression>"
      clause = operands.join(" #{self.normalize_operator(operator)} \n")
    when "is"
      operands = self.operands2humanvalue(exp[operator], options)
      clause = "#{operands.first} #{operator} #{operands.last}"
    when "between dates", "between times"
      col_name = exp[operator]["field"]
      col_type = self.get_col_type(col_name)
      col_human, dumy = self.operands2humanvalue(exp[operator], options)
      vals_human = exp[operator]["value"].collect {|v| self.quote_human(v, col_type)}
      clause = "#{col_human} #{operator} #{vals_human.first} AND #{vals_human.last}"
    when "from"
      col_name = exp[operator]["field"]
      col_type = self.get_col_type(col_name)
      col_human, dumy = self.operands2humanvalue(exp[operator], options)
      vals_human = exp[operator]["value"].collect {|v| self.quote_human(v, col_type)}
      clause = "#{col_human} #{operator} #{vals_human.first} THROUGH #{vals_human.last}"
    end

    # puts "clause: #{clause}"
    return clause
  end

  def to_ruby(tz=nil)
    tz ||= "UTC"
    @ruby ||= self.class._to_ruby(@exp.deep_clone, @context_type, tz)
    return @ruby.dup
  end

  def self._to_ruby(exp, context_type, tz)
    return exp unless exp.is_a?(Hash) || exp.is_a?(Array)

    operator = exp.keys.first
    case operator.downcase
    when "equal", "=", "<", ">", ">=", "<=", "!=", "before", "after"
      col_type = self.get_col_type(exp[operator]["field"]) if exp[operator]["field"]
      return self._to_ruby({"date_time_with_logical_operator" => exp}, context_type, tz) if col_type == :date || col_type == :datetime

      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      clause = operands.join(" #{self.normalize_ruby_operator(operator)} ")
    when "includes all"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      clause = "(#{operands[0]} & #{operands[1]}) == #{operands[1]}"
    when "includes any"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      clause = "(#{operands[1]} - #{operands[0]}) != #{operands[1]}"
    when "includes only", "limited to"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      clause = "(#{operands[0]} - #{operands[1]}) == []"
    when "like", "not like", "starts with", "ends with", "includes"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      case operator.downcase
      when "starts with"
        operands[1] = "/^" + self.re_escape(operands[1].to_s) + "/"
      when "ends with"
        operands[1] = "/"  + self.re_escape(operands[1].to_s) + "$/"
      else
        operands[1] = "/"  + self.re_escape(operands[1].to_s) + "/"
      end
      clause = operands.join(" #{self.normalize_ruby_operator(operator)} ")
      clause = "!(" + clause + ")" if operator.downcase == "not like"
    when "regular expression matches", "regular expression does not match"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      operands[1] = "/"  + operands[1].to_s + "/" unless operands[1].starts_with?("/") && (operands[1].ends_with?("/") || operands[1][-2..-2] == "/")
      clause = operands.join(" #{self.normalize_ruby_operator(operator)} ")
    when "and", "or"
      clause = "(" + exp[operator].collect {|operand| self._to_ruby(operand, context_type, tz)}.join(" #{self.normalize_ruby_operator(operator)} ") + ")"
    when "not", "!"
      clause = self.normalize_ruby_operator(operator) + "(" + self._to_ruby(exp[operator], context_type, tz) + ")"
    when "is null", "is not null", "is empty", "is not empty"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      clause = operands.join(" #{self.normalize_ruby_operator(operator)} ")
    when "contains"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      clause = operands.join(" #{self.normalize_operator(operator)} ")
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
      raise "expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'" unless check
      check =~ /^check(.*)$/; mode = $1.downcase
      clause = "<find><search>" + self._to_ruby(exp[operator]["search"], context_type, tz) + "</search><check mode=#{mode}>" + self._to_ruby(exp[operator][check], context_type, tz) + "</check></find>"
    when "key exists"
      clause = self.operands2rubyvalue(operator, exp[operator], context_type)
    when "value exists"
      clause = self.operands2rubyvalue(operator, exp[operator], context_type)
    when "ruby"
      operands = self.operands2rubyvalue(operator, exp[operator], context_type)
      col_type = self.get_col_type(exp[operator]["field"]) || "string"
      clause = "__start_ruby__ __start_context__#{operands[0]}__type__#{col_type}__end_context__ __start_script__#{operands[1]}__end_script__ __end_ruby__"
    when "is"
      col_name = exp[operator]["field"]
      col_ruby, dummy = self.operands2rubyvalue(operator, {"field" => col_name}, context_type)
      col_type = self.get_col_type(col_name)
      value = exp[operator]["value"]
      if col_type == :date
        if self.date_time_value_is_relative?(value)
          start_val = self.quote(self.normalize_date_time(value, "UTC", "beginning").to_date, :date)
          end_val   = self.quote(self.normalize_date_time(value, "UTC", "end").to_date, :date)
          clause    = "val=#{col_ruby}; !val.nil? && val.to_date >= #{start_val} && val.to_date <= #{end_val}"
        else
          value  = self.quote(self.normalize_date_time(value, "UTC", "beginning").to_date, :date)
          clause = "val=#{col_ruby}; !val.nil? && val.to_date == #{value}"
        end
      else
        start_val = self.quote(self.normalize_date_time(value, tz, "beginning").utc, :datetime)
        end_val   = self.quote(self.normalize_date_time(value, tz, "end").utc, :datetime)
        clause    = "val=#{col_ruby}; !val.nil? && val.to_time >= #{start_val} && val.to_time <= #{end_val}"
      end
    when "from"
      col_name = exp[operator]["field"]
      col_ruby, dummy = self.operands2rubyvalue(operator, {"field" => col_name}, context_type)
      col_type = self.get_col_type(col_name)

      start_val, end_val = exp[operator]["value"]
      start_val = self.quote(self.normalize_date_time(start_val, tz, "beginning").utc, :datetime)
      end_val   = self.quote(self.normalize_date_time(end_val, tz, "end").utc, :datetime)

      clause = "val=#{col_ruby}; !val.nil? && val.to_time >= #{start_val} && val.to_time <= #{end_val}"
    when "date_time_with_logical_operator"
      exp = exp[operator]
      operator = exp.keys.first

      col_name = exp[operator]["field"]
      col_type = self.get_col_type(col_name)
      col_ruby, dummy = self.operands2rubyvalue(operator, {"field" => col_name}, context_type)

      normalized_operator = self.normalize_ruby_operator(operator)
      mode = case normalized_operator
      when ">", "<="  then "end"        # (>  <date> 23::59:59), (<= <date> 23::59:59)
      when "<", ">="  then "beginning"  # (<  <date> 00::00:00), (>= <date> 00::00:00)
      end
      val = self.normalize_date_time(exp[operator]["value"], tz, mode)

      clause = "val=#{col_ruby}; !val.nil? && val.to_time #{normalized_operator} #{self.quote(val.utc, :datetime)}"
    else
      raise "operator '#{operator}' is not supported"
    end

    # puts "clause: #{clause}"
    return clause
  end

  def self.normalize_date_time(rel_time, tz, mode="beginning")
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

    if rt.starts_with?("this") || rt.starts_with?("last")
      # Convert these into the time spec form: <value> <interval> Ago
      value, interval = rt.split
      rt = "#{value == "this" ? 0 : 1} #{interval} ago"
    end

    if rt.ends_with?("ago")
      # Time spec <value> <interval> Ago
      value, interval, ago = rt.split
      interval = interval.pluralize

      if interval == "hours"
        self.beginning_or_end_of_hour(value.to_i.hours.ago.in_time_zone(tz), mode)
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
      self.beginning_or_end_of_hour(Time.now.in_time_zone(tz), mode)
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
    v.starts_with?("this") || v.starts_with?("last") || v.ends_with?("ago") || ["today", "yesterday", "now"].include?(v)
  end

  def to_sql(tz=nil)
    tz ||= "UTC"
    @pexp, attrs = self.preprocess_for_sql(@exp.deep_clone)
    sql = self._to_sql(@pexp, tz)
    incl = self.includes_for_sql unless sql.blank?
    return [sql, incl, attrs]
  end

  def _to_sql(exp, tz)
    return exp unless exp.is_a?(Hash) || exp.is_a?(Array)

    operator = exp.keys.first
    return if operator.nil?

    case operator.downcase
    when "equal", "=", "<", ">", ">=", "<=", "!=", "before", "after"
      col_type = self.class.get_col_type(exp[operator]["field"]) if exp[operator]["field"]
      return self._to_sql({"date_time_with_logical_operator" => exp}, tz) if col_type == :date || col_type == :datetime

      operands = self.class.operands2sqlvalue(operator, exp[operator])
      clause = operands.join(" #{self.class.normalize_sql_operator(operator)} ")
    when "like", "not like", "starts with", "ends with", "includes"
      operands = self.class.operands2sqlvalue(operator, exp[operator])
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
      operands = exp[operator].collect {|operand|
        o = self._to_sql(operand, tz)
        o.blank? ? nil : o
      }.compact
      if operands.length > 1
        clause = "(" + operands.join(" #{self.class.normalize_sql_operator(operator)} ") + ")"
      elsif operands.length == 1 # Operands may have been stripped out during pre-processing
        clause = "(" + operands.first + ")"
      else # All operands may have been stripped out during pre-processing
        clause = nil
      end
    when "not", "!"
      clause = self.class.normalize_sql_operator(operator) + " " + self._to_sql(exp[operator], tz)
    when "is null", "is not null"
      operands = self.class.operands2sqlvalue(operator, exp[operator])
      clause = "(#{operands[0]} #{self.class.normalize_sql_operator(operator)})"
    when "is empty", "is not empty"
      col      = exp[operator]["field"]
      col_type = self.col_details[col].nil? ? :string : self.col_details[col][:data_type]
      operands = self.class.operands2sqlvalue(operator, exp[operator])
      clause   = "(#{operands[0]} #{operator.sub(/empty/i, "NULL")})"
      if col_type == :string
        conjunction = (operator.downcase == 'is empty') ? 'OR' : 'AND'
        clause = "(#{clause} #{conjunction} (#{operands[0]} #{self.class.normalize_sql_operator(operator)} ''))"
      end
    when "contains"
      # Only support for tags of the main model
      if exp[operator].has_key?("tag")
        klass, ns = exp[operator]["tag"].split(".")
        ns  = "/" + ns.split("-").join("/")
        ns = ns.sub(/(\/user_tag\/)/, "/user/") # replace with correct namespace for user tags
        tag = exp[operator]["value"]
        klass = klass.constantize
        ids = klass.find_tagged_with(:any => tag, :ns => ns).pluck(:id)
        clause = "(#{klass.send(:sanitize_sql_for_conditions, :id => ids)})"
      else
        db, field = exp[operator]["field"].split(".")
        model = db.constantize
        assoc, field = field.split("-")
        ref = model.reflections[assoc.to_sym]
        inner_where = "#{field} = '#{exp[operator]["value"]}'"
        if cond = ref.options.fetch(:conditions, nil)          # Include ref.options[:conditions] in inner select if exists
          cond = ref.options[:class_name].constantize.send(:sanitize_sql_for_assignment, cond)
          inner_where = "(#{inner_where}) AND (#{cond})"
        end
        clause = "#{model.table_name}.id IN (SELECT DISTINCT #{ref.foreign_key} FROM #{ref.table_name} WHERE #{inner_where})"
      end
    when "is"
      col_name = exp[operator]["field"]
      col_sql, dummy = self.class.operands2sqlvalue(operator, {"field" => col_name})
      col_type = self.class.get_col_type(col_name)
      value = exp[operator]["value"]
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
      col_name = exp[operator]["field"]
      col_sql, dummy = self.class.operands2sqlvalue(operator, {"field" => col_name})
      col_type = self.class.get_col_type(col_name)

      start_val, end_val = exp[operator]["value"]
      start_val = self.class.quote(self.class.normalize_date_time(start_val, tz, "beginning").utc, :datetime, :sql)
      end_val   = self.class.quote(self.class.normalize_date_time(end_val, tz, "end").utc, :datetime, :sql)

      clause = "#{col_sql} BETWEEN #{start_val} AND #{end_val}"
    when "date_time_with_logical_operator"
      exp = exp[operator]
      operator = exp.keys.first

      col_name = exp[operator]["field"]
      col_type = self.class.get_col_type(col_name)
      col_sql, dummy = self.class.operands2sqlvalue(operator, {"field" => col_name})

      normalized_operator = self.class.normalize_sql_operator(operator)
      mode = case normalized_operator
      when ">", "<="  then "end"        # (>  <date> 23::59:59), (<= <date> 23::59:59)
      when "<", ">="  then "beginning"  # (<  <date> 00::00:00), (>= <date> 00::00:00)
      end
      val = self.class.normalize_date_time(exp[operator]["value"], tz, mode)

      clause = "#{col_sql} #{normalized_operator} #{self.class.quote(val.utc, :datetime, :sql)}"
    else
      raise "operator '#{operator}' is not supported"
    end

    # puts "clause: #{clause}"
    return clause
  end

  def preprocess_for_sql(exp, attrs=nil)
    attrs ||= {:supported_by_sql => true}
    operator = exp.keys.first
    case operator.downcase
    when "and"
      exp[operator].dup.each { |atom| self.preprocess_for_sql(atom, attrs)}
      exp[operator] = exp[operator].collect {|o| o.blank? ? nil : o}.compact # Clean out empty operands
      exp.delete(operator) if exp[operator].empty?
    when "or"
      or_attrs = {:supported_by_sql => true}
      exp[operator].each_with_index { |atom,i|
        self.preprocess_for_sql(atom, or_attrs)
        exp[operator][i] = nil if atom.blank?
      }
      exp[operator].compact!
      attrs.merge!(or_attrs)
      exp.delete(operator) if !or_attrs[:supported_by_sql] || exp[operator].empty? # Clean out unsupported or empty operands
    when "not"
      self.preprocess_for_sql(exp[operator], attrs)
      exp.delete(operator) if exp[operator].empty? # Clean out empty operands
    else
      # check operands to see if they can be represented in sql
      unless sql_supports_atom?(exp)
        attrs[:supported_by_sql] = false
        exp.delete(operator)
      end
    end

    return exp.empty? ? [nil, attrs] : [exp, attrs]
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
        ref = db.constantize.reflections[assoc.to_sym]
        return false unless ref
        return false unless ref.macro == :has_many || ref.macro == :has_one
        return false if ref.options && ref.options.has_key?(:as)
        return field_in_sql?(exp[operator]["field"])
      else
        return false
      end
    when "includes"
      # Support includes operator using "LIKE" only if first operand is in main table
      if exp[operator].has_key?("field") && (!exp[operator]["field"].include?(".") || (exp[operator]["field"].include?(".") && exp[operator]["field"].split(".").length == 2))
        return field_in_sql?(exp[operator]["field"])
      else
        # TODO: Support includes operator for sub-sub-tables
        return false
      end
    when "find", "regular expression matches", "regular expression does not match", "key exists", "value exists", "ruby"
      return false
    else
      # => false if operand is a tag
      return false if exp[operator].keys.include?("tag")

      # => TODO: support count of child relationship
      return false if exp[operator].has_key?("count")

      return field_in_sql?(exp[operator]["field"])
    end
  end

  def field_in_sql?(field)
    # => false if operand is from a virtual reflection
    return false if self.field_from_virtual_reflection?(field)

    # => false if operand if a virtual coulmn
    return false if self.field_is_virtual_column?(field)

    # => false if excluded by special case defined in preprocess options
    return false if self.field_excluded_by_preprocess_options?(field)

    return true
  end

  def field_from_virtual_reflection?(field)
    self.col_details[field][:virtual_reflection]
  end

  def field_is_virtual_column?(field)
    self.col_details[field][:virtual_column]
  end

  def field_excluded_by_preprocess_options?(field)
    self.col_details[field][:excluded_by_preprocess_options]
  end

  def col_details
    @col_details ||= self.class.get_cols_from_expression(@exp, @preprocess_options)
  end

  def includes_for_sql
    result = {}
    self.col_details.each_value do |v|
      self.class.deep_merge_hash(result, v[:include])
    end
    return result
  end

  def columns_for_sql(exp=nil, result = nil)
    exp    ||= self.exp
    result ||= []
    return result unless exp.kind_of?(Hash)

    operator = exp.keys.first
    if exp[operator].kind_of?(Hash) && exp[operator].has_key?("field")
      unless exp[operator]["field"] == "<count>" || self.field_from_virtual_reflection?(exp[operator]["field"]) || self.field_is_virtual_column?(exp[operator]["field"])
        col = exp[operator]["field"]
        if col.include?(".")
          col = col.split(".").last
          col = col.sub("-", ".")
        else
          col = col.split("-").last
        end
        result << col
      end
    else
      exp[operator].dup.to_miq_a.each { |atom| self.columns_for_sql(atom, result) }
    end

    return result.compact.uniq
  end

  def self.deep_merge_hash(hash1,hash2)
    return hash1 if hash2.nil?
    hash2.each_key do |k1|
      if hash1.key?(k1)
        deep_merge_hash(hash1[k1],hash2[k1])
      else
        hash1[k1] = hash2[k1]
      end
    end
  end

  def self.merge_where_clauses_and_includes(where_clauses, includes)
    [self.merge_where_clauses(*where_clauses), self.merge_includes(*includes)]
  end

  def self.merge_where_clauses(*list)
    l = list.compact.collect do |s|
      s = MiqReport.send(:sanitize_sql_for_conditions, s)
      "(#{s})"
    end
    return l.empty? ? nil : l.join(" AND ")
  end

  def self.merge_includes(*incl_list)
    return nil if incl_list.blank?
    result = {}
    incl_list.each do |i|
      self.deep_merge_hash(result, i)
    end
    return result
  end

  def self.get_cols_from_expression(exp, options={})
    result = {}
    if exp.kind_of?(Hash)
      if exp.has_key?("field")
        result[exp["field"]] = self.get_col_info(exp["field"], options) unless exp["field"] == "<count>"
      elsif exp.has_key?("count")
        result[exp["count"]] = self.get_col_info(exp["count"], options)
      elsif exp.has_key?("tag")
        # ignore
      else
        exp.each_value { |v| result.merge!(self.get_cols_from_expression(v, options)) }
      end
    elsif exp.kind_of?(Array)
      exp.each {|v| result.merge!(self.get_cols_from_expression(v, options)) }
    end
    return result
  end

  def self.get_col_info(field, options={})
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
      ref = model.reflections_with_virtual[assoc]
      result[:virtual_reflection] = true if ref.kind_of?(VirtualReflection)

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
      result[:data_type] = self.col_type(model, col)
      result[:format_sub_type] = MiqReport::FORMAT_DEFAULTS_AND_OVERRIDES[:sub_types_by_column][col.to_sym] || result[:data_type]
      result[:virtual_column] = true if model.virtual_columns_hash.include?(col.to_s)
      result[:excluded_by_preprocess_options] = self.exclude_col_by_preprocess_options?(col, options)
    end
    return result
  end

  def self.exclude_col_by_preprocess_options?(col, options)
    return false unless options.kind_of?(Hash)

    if options[:vim_performance_daily_adhoc]
      return VimPerformanceDaily.excluded_cols_for_expressions.include?(col.to_sym)
    end

    return false
  end

  def self.evaluate(expression, obj, inputs={})
    ruby_exp = expression.is_a?(Hash) ? self.new(expression).to_ruby : expression.to_ruby
    $log.debug("MIQ(Expression-evaluate) Expression before substitution: #{ruby_exp}")
    subst_expr = self.subst(ruby_exp, obj, inputs)
    $log.debug("MIQ(Expression-evaluate) Expression after substitution: #{subst_expr}")
    result = eval(subst_expr) ? true : false
    $log.debug("MIQ(Expression-evaluate) Expression evaluation result: [#{result}]")
    return result
  end

  def evaluate(obj, inputs={})
    self.class.evaluate(self, obj, inputs)
  end

  def self.evaluate_atoms(exp, obj, inputs={})
    exp = exp.is_a?(self) ? copy_hash(exp.exp) : exp
    exp["result"] = self.evaluate(exp, obj, inputs)

    operators = exp.keys
    operators.each {|k|
      if ["and", "or"].include?(k.to_s.downcase)      # and/or atom is an array of atoms
        exp[k].each {|atom|
          self.evaluate_atoms(atom, obj, inputs)
        }
      elsif ["not", "!"].include?(k.to_s.downcase)    # not atom is a hash expression
        self.evaluate_atoms(exp[k], obj, inputs)
      else
        next
      end
    }
    return exp
  end

  def self.subst(ruby_exp, obj, inputs)
    Condition.subst(ruby_exp, obj, inputs)
  end

  def self.operands2humanvalue(ops, options={})
    # puts "Enter: operands2humanvalue: ops: #{ops.inspect}"
    ret = []
    if ops["tag"]
      v = nil
      ret.push(ops["alias"] || self.value2human(ops["tag"], options))
      MiqExpression.get_entry_details(ops["tag"]).each {|t|
        v = "'" + t.first + "'" if t.last == ops["value"]
      }
      if ops["value"] == :user_input
        v = "<user input>"
      else
        v ||= ops["value"].is_a?(String) ? "'" + ops["value"] + "'" : ops["value"]
      end
      ret.push(v)
    elsif ops["field"]
      ops["value"] ||= ''
      if ops["field"] == "<count>"
        ret.push(nil)
        ret.push(ops["value"])
      else
        ret.push(ops["alias"] || self.value2human(ops["field"], options))
        if ops["value"] == :user_input
          ret.push("<user input>")
        else
          col_type = self.get_col_type(ops["field"]) || "string"
          ret.push(self.quote_human(ops["value"], col_type.to_s))
        end
      end
    elsif ops["count"]
      ret.push("COUNT OF " + (ops["alias"] || self.value2human(ops["count"], options)).strip)
      if ops["value"] == :user_input
        ret.push("<user input>")
      else
        ret.push(ops["value"])
      end
    elsif ops["regkey"]
      ops["value"] ||= ''
      ret.push(ops["regkey"] + " : " + ops["regval"])
      ret.push(ops["value"].is_a?(String) ? "'" + ops["value"] + "'" : ops["value"])
    elsif ops["value"]
      ret.push(nil)
      ret.push(ops["value"])
    end
    return ret
  end

  def self.value2human(val, options={})
    options = {
      :include_model => true,
      :include_table => true
    }.merge(options)
    @company ||= VMDB::Config.new("vmdb").config[:server][:company]
    tables, col = val.split("-")
    first = true
    val_is_a_tag = false
    ret = ""
    if options[:include_table] == true
      friendly = tables.split(".").collect {|t|
        if t.downcase == "managed"
          val_is_a_tag = true
          @company + " Tags"
        elsif t.downcase == "user_tag"
          "My Tags"
        else
          if first
            first = nil
            next unless options[:include_model] == true
            Dictionary.gettext(t, :type=>:model, :notfound=>:titleize)
          else
            Dictionary.gettext(t, :type=>:table, :notfound=>:titleize)
          end
        end
      }.compact
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
      ret << Dictionary.gettext(dict_col, :type=>:column, :notfound=>:titleize) if col
    end
    ret = " #{ret}" unless ret.include?(":")
    ret
  end

  def self.operands2sqlvalue(operator, ops)
    # puts "Enter: operands2rubyvalue: operator: #{operator}, ops: #{ops.inspect}"
    operator = operator.downcase

    ret = []
    if  ops["field"]
      ret << self.get_sqltable(ops["field"].split("-").first) + "." + ops["field"].split("-").last
      col_type = self.get_col_type(ops["field"]) || "string"
      if ["like", "not like", "starts with", "ends with", "includes"].include?(operator)
        ret.push(ops["value"])
      else
        ret.push(self.quote(ops["value"], col_type.to_s, :sql))
      end
    elsif ops["count"]
      val = self.get_sqltable(ops["count"].split("-").first) + "." + ops["count"].split("-").last
      ret << "count(#{val})" #TODO
      ret.push(ops["value"])
    else
      return nil
    end
    return ret
  end

  def self.operands2rubyvalue(operator, ops, context_type)
    # puts "Enter: operands2rubyvalue: operator: #{operator}, ops: #{ops.inspect}"
    operator = operator.downcase
    ops["tag"] = ops["field"] if operator == "contains" and !ops["tag"] # process values in contains as tags

    ret = []
    if ops["tag"] && context_type != "hash"
      ref, val = self.value2tag(self.preprocess_managed_tag(ops["tag"]), ops["value"])
      fld = val
      ret.push(ref ? "<exist ref=#{ref}>#{val}</exist>" : "<exist>#{val}</exist>")
    elsif ops["tag"] && context_type == "hash"
      # This is only for supporting reporting "display filters"
      # In the report object the tag value is actually the description and not the raw tag name.
      # So we have to trick it by replacing the value with the description.
      description = MiqExpression.get_entry_details(ops["tag"]).inject("") {|s,t|
        break(t.first) if t.last == ops["value"]
        s
      }

      val = ops["tag"].split(".").last.split("-").join(".")
      fld = "<value type=string>#{val}</value>"
      ret.push(fld)
      ret.push(self.quote(description, "string"))
    elsif ops["field"]
      if ops["field"] == "<count>"
        ret.push("<count>")
        ret.push(ops["value"])
      else
        case context_type
        when "hash"
          ref = nil
          val = ops["field"].split(".").last.split("-").join(".")
        else
          ref, val = self.value2tag(ops["field"])
        end
        col_type = self.get_col_type(ops["field"]) || "string"
        col_type = "raw" if operator == "ruby"
        fld = val
        fld = ref ? "<value ref=#{ref}, type=#{col_type}>#{val}</value>" : "<value type=#{col_type}>#{val}</value>"
        ret.push(fld)
        if ["like", "not like", "starts with", "ends with", "includes", "regular expression matches", "regular expression does not match", "ruby"].include?(operator)
          ret.push(ops["value"])
        else
          ret.push(self.quote(ops["value"], col_type.to_s))
        end
      end
    elsif ops["count"]
      ref, count = self.value2tag(ops["count"])
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
        ret.push(self.quote(ops["value"], "string"))
      end
    end
    return ret
  end

  def self.quote(val, typ, mode=:ruby)
    case typ.to_s
    when "string", "text", "boolean", nil
      val = "" if val.nil? # treat nil value as empty string
      return mode == :sql ? ActiveRecord::Base.connection.quote(val) : "'" + val.to_s.gsub(/'/, "\\\\'") + "'" # escape any embedded single quotes
    when "date"
      return "nil" if val.blank? # treat nil value as empty string
      return mode == :sql ? ActiveRecord::Base.connection.quote(val) : "\'#{val}\'.to_date"
    when "datetime"
      return "nil" if val.blank? # treat nil value as empty string
      return mode == :sql ? ActiveRecord::Base.connection.quote(val.iso8601) : "\'#{val.iso8601}\'.to_time"
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
        if sfx.ends_with?("bytes") && FORMAT_BYTE_SUFFIXES.has_key?(sfx.to_sym)
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
      return self.quote(val, typ)
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
      while path_arr.first != "managed" && path_arr.first != "user_tag" do
        name = path_arr.shift
      end
      return [name].concat(path_arr).join(".") + "-" + val
    end
    return tag
  end

  def self.value2tag(tag, val=nil)
    val = val.to_s.gsub(/\//, "%2f") unless val.nil? #encode embedded / characters in values since / is used as a tag seperator
    v = tag.to_s.split(".").compact.join("/") #split model path and join with "/"
    v = v.to_s.split("-").join("/") #split out column name and join with "/"
    v = [v, val].join("/") #join with value
    v_arr = v.split("/")
    ref = v_arr.shift #strip off model (eg. VM)
     v_arr[0] = "user" if v_arr.first == "user_tag"
    v_arr.unshift("virtual") unless v_arr.first == "managed" || v_arr.first == "user" #add in tag designation
    return [ref.downcase, "/" + v_arr.join("/")]
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
    parts.reverse.each do |assoc|
      ref = klass.reflections[assoc.to_sym]
      if ref.nil?
        klass = nil
        break
      end
      klass = ref.class_name.constantize
    end

    return klass ? klass.table_name : name.pluralize.underscore
  end

  def self.base_tables
    @@base_tables
  end

  def self.model_details(model, opts = {:typ=>"all", :include_model=>true, :include_tags=>false, :include_my_tags=>false})
    @classifications = nil
    model = model.to_s

    opts = {:typ=>"all", :include_model=>true}.merge(opts)
    if opts[:typ] == "tag"
      tags_for_model = self.tag_details(model, model, opts)
      result = []

      TAG_CLASSES.each_slice(2) {|tc, name|
        next if tc.constantize.base_class == model.constantize.base_class
        path = [model, name].join(".")
        result.concat(self.tag_details(tc, path, opts))
      }
      @classifications = nil
      return tags_for_model.concat(result.sort!{|a,b|a.to_s<=>b.to_s})
    end

    relats = self.get_relats(model)

    result = []
    unless opts[:typ] == "count" || opts[:typ] == "find"
      result = self.get_column_details(relats[:columns], model, opts).sort!{|a,b|a.to_s<=>b.to_s}
      result.concat(self.tag_details(model, model, opts)) if opts[:include_tags] == true
    end
    result.concat(self._model_details(relats, opts).sort!{|a,b|a.to_s<=>b.to_s})
    @classifications = nil
    return result
  end

  def self._model_details(relats, opts)
    result = []
    relats[:reflections].each {|assoc, ref|
      case opts[:typ]
      when "count"
        result.push(self.get_table_details(ref[:parent][:path])) if ref[:parent][:multivalue]
      when "find"
        result.concat(self.get_column_details(ref[:columns], ref[:parent][:path], opts)) if ref[:parent][:multivalue]
      else
        result.concat(self.get_column_details(ref[:columns], ref[:parent][:path], opts))
        result.concat(self.tag_details(ref[:parent][:assoc_class], ref[:parent][:path], opts)) if opts[:include_tags] == true
      end

      result.concat(self._model_details(ref, opts))
    }
    return result
  end

  def self.tag_details(model, path, opts)
    return [] unless TAG_CLASSES.include?(model)
    result = []
    @classifications ||= self.get_categories
    @classifications.each {|name,cat|
      prefix = path.nil? ? "managed" : [path, "managed"].join(".")
      field = prefix + "-" + name
      result.push([self.value2human(field, opts.merge(:classification => cat)), field])
    }
    if opts[:include_my_tags] && opts[:userid] && Tag.exists?(["name like ?", "/user/#{opts[:userid]}/%"])
      prefix = path.nil? ? "user_tag" : [path, "user_tag"].join(".")
      field = prefix + "-" + opts[:userid]
      result.push([self.value2human(field, opts), field])
    end
    result.sort!{|a,b|a.to_s<=>b.to_s}
  end

  def self.get_relats(model)
    @model_relats ||= {}
    @model_relats[model] ||= self.build_relats(model)
  end

  def self.build_lists(model)
    $log.info("MIQ(MiqExpression-build_lists) Building lists for: [#{model}]...")

    # Build expression lists
    [:exp_available_fields, :exp_available_counts, :exp_available_finds].each {|what| self.miq_adv_search_lists(model, what)}

    # Build reporting lists
    self.reporting_available_fields(model) unless model == model.ends_with?("Trend") || model.ends_with?("Performance") # Can't do trend/perf models at startup
  end

  def self.miq_adv_search_lists(model, what)
    @miq_adv_search_lists ||= {}
    @miq_adv_search_lists[model.to_s] ||= {}

    case what.to_sym
    when :exp_available_fields then @miq_adv_search_lists[model.to_s][:exp_available_fields] ||= MiqExpression.model_details(model, :typ=>"field", :include_model=>true)
    when :exp_available_counts then @miq_adv_search_lists[model.to_s][:exp_available_counts] ||= MiqExpression.model_details(model, :typ=>"count", :include_model=>true)
    when :exp_available_finds  then @miq_adv_search_lists[model.to_s][:exp_available_finds]  ||= MiqExpression.model_details(model, :typ=>"find",  :include_model=>true)
    end
  end

  def self.reporting_available_fields(model, interval = nil)
    @reporting_available_fields ||= {}
    if model.to_s == "VimPerformanceTrend"
      @reporting_available_fields[model.to_s] ||= {}
      @reporting_available_fields[model.to_s][interval.to_s] ||= VimPerformanceTrend.trend_model_details(interval.to_s)
    elsif model.ends_with?("Performance")
      @reporting_available_fields[model.to_s] ||= {}
      @reporting_available_fields[model.to_s][interval.to_s] ||= MiqExpression.model_details(model, :include_model => false, :include_tags => true, :interval =>interval)
    elsif model.to_s == "Chargeback"
      @reporting_available_fields[model.to_s] ||= MiqExpression.model_details(model, :include_model=>false, :include_tags=>true).select {|c| c.last.ends_with?("_cost") || c.last.ends_with?("_metric") || c.last.ends_with?("-owner_name")}
    else
      @reporting_available_fields[model.to_s] ||=  MiqExpression.model_details(model, :include_model=>false, :include_tags=>true)
    end
  end

  def self.build_relats(model, parent={}, seen=[])
    $log.info("MIQ(MiqExpression.build_relats) Building relationship tree for: [#{parent[:path]} => #{model}]...")

    model = model_class(model)

    parent[:path] ||= model.name
    parent[:root] ||= model.name
    result = {:columns => model.column_names_with_virtual, :parent => parent}
    result[:reflections] = {}

    model.reflections_with_virtual.each do |assoc, ref|
      next unless @@include_tables.include?(assoc.to_s.pluralize)
      next if     assoc.to_s.pluralize == "event_logs" && parent[:root] == "Host" && !@@proto
      next if     assoc.to_s.pluralize == "processes"  && parent[:root] == "Host" # Process data not available yet for Host

      next if ref.macro == :belongs_to && model.name != parent[:root]

      assoc_class = ref.klass.name

      new_parent = {
        :macro       => ref.macro,
        :path        => [parent[:path], assoc.to_s].join("."),
        :assoc       => assoc,
        :assoc_class => assoc_class,
        :root        => parent[:root]
      }
      new_parent[:direction] = new_parent[:macro] == :belongs_to ? :up : :down
      new_parent[:multivalue] = [:has_many, :has_and_belongs_to_many].include?(new_parent[:macro])

      seen_key = [model.name, assoc].join("_")
      unless seen.include?(seen_key) ||
             assoc_class == parent[:root] ||
             parent[:path].include?(assoc.to_s) ||
             parent[:path].include?(assoc.to_s.singularize) ||
             parent[:direction] == :up ||
             parent[:multivalue]
        seen.push(seen_key)
        result[:reflections][assoc] = self.build_relats(assoc_class, new_parent, seen)
      end
    end
    result
  end

  def self.get_table_details(table)
# puts "Enter: get_table_details: model: #{model}, parent: #{parent.inspect}"
    [self.value2human(table), table]
  end

  def self.get_column_details(column_names, parent, opts)
    include_model = opts[:include_model]
    base_model = parent.split(".").first

    excludes =  EXCLUDE_COLUMNS
    # special case for C&U ad-hoc reporting
    if opts[:interval] && opts[:interval] != "daily" && base_model.ends_with?("Performance") && !parent.include?(".")
      excludes += ["^min_.*$", "^max_.*$", "^.*derived_storage_.*$", "created_on"]
    elsif opts[:interval] && base_model.ends_with?("Performance") && !parent.include?(".")
      excludes += ["created_on"]
    end

    excludes += ["logical_cpus"] if parent == "Vm.hardware"

    case base_model
    when "VmPerformance"
      excludes += ["^.*derived_host_count_off$", "^.*derived_host_count_on$", "^.*derived_vm_count_off$", "^.*derived_vm_count_on$", "^.*derived_storage.*$"]
    when "HostPerformance"
      excludes += ["^.*derived_host_count_off$", "^.*derived_host_count_on$", "^.*derived_storage.*$", "^abs_.*$"]
    when "EmsClusterPerformance"
      excludes += ["^.*derived_storage.*$", "sys_uptime_absolute_latest", "^abs_.*$"]
    when "StoragePerformance"
      includes = ["^.*derived_storage.*$", "^timestamp$", "v_date", "v_time", "resource_name"]
      column_names = column_names.collect { |c|
        next(c) if includes.include?(c)
        c if includes.detect {|incl| c.match(incl) }
      }.compact
    end

    column_names.collect {|c|
      # check for direct match first
      next if excludes.include?(c) && !EXCLUDE_EXCEPTIONS.include?(c)

      # check for regexp match if no direct match
      col = c
      excludes.each {|excl|
        if c.match(excl)
          col = nil
          break
        end
      } unless EXCLUDE_EXCEPTIONS.include?(c)
      if col
        field = parent + "-" + col
        [self.value2human(field, :include_model => include_model), field]
      end
    }.compact
  end

  def self.get_col_type(field)
    model, parts, col = self.parse_field(field)

    return :string if model.downcase == "managed" || parts.last == "managed"
    return nil unless field.include?("-")

    model = self.determine_model(model, parts)
    return nil if model.nil?

    self.col_type(model, col)
  end

  def self.col_type(model, col)
    model = model_class(model)
    col = model.columns_hash_with_virtual[col.to_s]
    return col.nil? ? nil : col.type
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
                       "REGULAR EXPRESSION DOES NOT MATCH",
                       "RUBY"]
  SET_OPERATORS     = ["INCLUDES ALL",
                       "INCLUDES ANY",
                       "LIMITED TO",
                       "RUBY"]
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
      col_type = self.get_col_type(field.to_s) || :string
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
    result = self.get_col_operators(field) - STYLE_OPERATORS_EXCLUDES
  end

  def self.get_entry_details(field)
    ns = field.split("-").first.split(".").last

    if ns == "managed"
      cat = field.split("-").last
      catobj = Classification.find_by_name(cat)
      return catobj ? catobj.entries.collect {|e| [e.description, e.name]} : []
    elsif ns == "user_tag" || ns == "user"
      cat = field.split("-").last
      return Tag.find(:all, :conditions => ["name like ?", "/user/#{cat}%"]).collect {|t| [t.name.split("/").last, t.name.split("/").last]}
    else
      return field
    end
  end

  def self.is_plural?(field)
    parts = field.split("-").first.split(".")
    macro = nil
    model = model_class(parts.shift)
    parts.each do |assoc|
      ref = model.reflections_with_virtual[assoc.to_sym]
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
    when "regular expression matches", "regular expression does not match" #TODO
      :regexp
    else
      if field == :count
        :integer
      else
        col_info = self.get_col_info(field)
        [:bytes, :megabytes].include?(col_info[:format_sub_type]) ? :integer : col_info[:data_type]
      end
    end

    case dt
    when :string, :text
      return false
    when :integer, :fixnum, :decimal, :float
      return false if self.send((dt == :float ? :is_numeric? : :is_integer?), value)

      dt_human = dt == :float ? "Number" : "Integer"
      return "#{dt_human} value must not be blank" if value.gsub(/,/, "").blank?

      if value.include?(".") && (value.split(".").last =~ /([a-z]+)/i)
        sfx = $1
        sfx = sfx.ends_with?("bytes") && FORMAT_BYTE_SUFFIXES.has_key?(sfx.to_sym) ? FORMAT_BYTE_SUFFIXES[sfx.to_sym] : sfx.titleize
        value = "#{value.split(".")[0..-2].join(".")} #{sfx}"
      end

      return "Value '#{value}' is not a valid #{dt_human}"
    when :date, :datetime
      return false if operator.downcase.include?("empty")

      values = value.to_miq_a
      return "No Date/Time value specified" if values.empty? || values.include?(nil)
      return "Two Date/Time values must be specified" if operator.downcase == "from" && values.length < 2

      values_converted = values.collect do |v|
        return "Date/Time value must not be blank" if value.blank?
        v_cvt = self.normalize_date_time(v, "UTC") rescue nil
        return "Value '#{v}' is not valid" if v_cvt.nil?
        v_cvt
      end
      return "Invalid Date/Time range, #{values[1]} comes before #{values[0]}" if values_converted.length > 1 && values_converted[0] > values_converted[1]
      return false
    when :boolean
      return "Value must be true or false" unless operator.downcase.include?("null") || ["true", "false"].include?(value)
      return false
    when :regexp
      begin
        Regexp.new(value).match("foo")
      rescue => err
        return "Regular expression '#{value}' is invalid, '#{err.message}'"
      end
      return false
    when :ruby
      return "Ruby Script must not be blank" if value.blank?
      return false
    else
      return false
    end

    return "Value '#{value}' must be in the form of #{FORMAT_SUB_TYPES[dt][:short_name]}"
  end

  def self.get_categories
    classifications = Classification.in_my_region.hash_all_by_type_and_name(:show => true)
    categories_with_entries = classifications.reject { |k, v| !v.has_key?(:entry) }
    categories_with_entries.each_with_object({}) do |(name, hash), categories|
      categories[name] = hash[:category]
    end
  end

  def self.model_class(model)
    # TODO: the temporary cache should be removed after widget refactoring
    @@model_class ||= Hash.new { |h, m| h[m] = m.is_a?(Class) ? m: m.to_s.singularize.camelize.constantize rescue nil }
    @@model_class[model]
  end

  def self.is_integer?(n)
    n = n.to_s
    n2 = n.gsub(/,/, "") # strip out commas
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
    n2 = n.gsub(/,/, "") # strip out commas
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
    return exp.quick_search? if exp.is_a?(self)
    return self._quick_search?(exp)
  end

  def quick_search?
    self.class._quick_search?(self.exp)  # Pass the exp hash
  end

  # Is an expression hash a quick search?
  def self._quick_search?(e)
    if e.is_a?(Array)
      e.each { |e_exp| return true if self._quick_search?(e_exp) }
    elsif e.is_a?(Hash)
      return true if e["value"] == :user_input
      e.each_value {|e_exp| return true if self._quick_search?(e_exp)}
    end
    return false
  end

  private

  def self.determine_model(model, parts)
    model = model_class(model)
    return nil if model.nil?

    parts.each do |assoc|
      ref = model.reflections_with_virtual[assoc.to_sym]
      return nil if ref.nil?
      model = ref.klass
    end

    model
  end
end #class MiqExpression
