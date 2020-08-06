class MiqExpression
  require_nested :Tag
  include Vmdb::Logging
  attr_accessor :exp, :context_type, :preprocess_options

  config = YAML.load(ERB.new(File.read(Rails.root.join("config", "miq_expression.yml"))).result) # rubocop:disable Security/YAMLLoad
  BASE_TABLES = config[:base_tables]
  INCLUDE_TABLES = config[:include_tables]
  EXCLUDE_COLUMNS = config[:exclude_columns]
  EXCLUDE_ID_COLUMNS = config[:exclude_id_columns]
  EXCLUDE_EXCEPTIONS = config[:exclude_exceptions]
  TAG_CLASSES = config[:tag_classes]
  EXCLUDE_FROM_RELATS = config[:exclude_from_relats]
  FORMAT_SUB_TYPES = config[:format_sub_types]
  FORMAT_BYTE_SUFFIXES = FORMAT_SUB_TYPES[:bytes][:units].to_h.invert
  BYTE_FORMAT_WHITELIST = Hash[FORMAT_BYTE_SUFFIXES.keys.collect(&:to_s).zip(FORMAT_BYTE_SUFFIXES.keys)]
  NUM_OPERATORS        = config[:num_operators].freeze
  STRING_OPERATORS     = config[:string_operators]
  SET_OPERATORS        = config[:set_operators]
  REGKEY_OPERATORS     = config[:regkey_operators]
  BOOLEAN_OPERATORS    = config[:boolean_operators]
  DATE_TIME_OPERATORS  = config[:date_time_operators]
  DEPRECATED_OPERATORS = config[:deprecated_operators]
  UNQUOTABLE_OPERATORS = (STRING_OPERATORS + DEPRECATED_OPERATORS - ['=', 'IS NULL', 'IS NOT NULL', 'IS EMPTY', 'IS NOT EMPTY']).freeze

  def initialize(exp, ctype = nil)
    @exp = exp
    @context_type = ctype
    @col_details = nil
    @ruby = nil
  end

  def valid?(component = exp)
    operator = component.keys.first
    case operator.downcase
    when "and", "or"
      component[operator].all?(&method(:valid?))
    when "not", "!"
      valid?(component[operator])
    when "find"
      validate_set = Set.new(%w(checkall checkany checkcount search))
      validate_keys = component[operator].keys.select { |k| validate_set.include?(k) }
      validate_keys.all? { |k| valid?(component[operator][k]) }
    else
      if component[operator].key?("field")
        field = Field.parse(component[operator]["field"])
        return false if field && !field.valid?
      end
      if Field.is_field?(component[operator]["value"])
        field = Field.parse(component[operator]["value"])
        return false unless field && field.valid?
      end
      true
    end
  end

  def set_tagged_target(model, associations = [])
    each_atom(exp) do |atom|
      next unless atom.key?("tag")
      tag = Tag.parse(atom["tag"])
      tag.model = model
      tag.associations = associations
      atom["tag"] = tag.to_s
    end
  end

  def self.proto?
    return @proto if defined?(@proto)
    @proto = ::Settings.product.proto
  end

  def self.to_human(exp)
    if exp.kind_of?(self)
      exp.to_human
    elsif exp.kind_of?(Hash)
      case exp["mode"]
      when "tag_expr"
        exp["expr"]
      when "tag"
        tag = [exp["ns"], exp["tag"]].join("/")
        if exp["include"] == "none"
          return "Not Tagged With #{tag}"
        else
          return "Tagged With #{tag}"
        end
      when "script"
        if exp["expr"] == "true"
          "Always True"
        else
          exp["expr"]
        end
      else
        new(exp).to_human
      end
    else
      exp.inspect
    end
  end

  def to_human
    self.class._to_human(exp)
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
      check =~ /^check(.*)$/
      mode = $1.upcase
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
      col_type = parse_field_or_tag(col_name)&.column_type
      col_human, _value = operands2humanvalue(exp[operator], options)
      vals_human = exp[operator]["value"].collect { |v| quote_human(v, col_type) }
      clause = "#{col_human} #{operator} #{vals_human.first} AND #{vals_human.last}"
    when "from"
      col_name = exp[operator]["field"]
      col_type = parse_field_or_tag(col_name)&.column_type
      col_human, _value = operands2humanvalue(exp[operator], options)
      vals_human = exp[operator]["value"].collect { |v| quote_human(v, col_type) }
      clause = "#{col_human} #{operator} #{vals_human.first} THROUGH #{vals_human.last}"
    end

    # puts "clause: #{clause}"
    clause
  end

  def to_ruby(tz = nil)
    return "" unless valid?
    tz ||= "UTC"
    @ruby ||= self.class._to_ruby(exp.deep_clone, context_type, tz)
    @ruby.dup
  end

  def self._to_ruby(exp, context_type, tz)
    return exp unless exp.kind_of?(Hash)

    operator = exp.keys.first
    op_args = exp[operator]
    col_name = op_args["field"] if op_args.kind_of?(Hash)
    operator = operator.downcase

    case operator
    when "equal", "=", "<", ">", ">=", "<=", "!="
      operands = operands2rubyvalue(operator, op_args, context_type)
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "before"
      col_type = parse_field_or_tag(col_name)&.column_type if col_name
      col_ruby, _value = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      val = op_args["value"]
      clause = ruby_for_date_compare(col_ruby, col_type, tz, "<", val)
    when "after"
      col_type = parse_field_or_tag(col_name)&.column_type if col_name
      col_ruby, _value = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      val = op_args["value"]
      clause = ruby_for_date_compare(col_ruby, col_type, tz, nil, nil, ">", val)
    when "includes all"
      operands = operands2rubyvalue(operator, op_args, context_type)
      clause = "(#{operands[0]} & #{operands[1]}) == #{operands[1]}"
    when "includes any"
      operands = operands2rubyvalue(operator, op_args, context_type)
      clause = "(#{operands[1]} - #{operands[0]}) != #{operands[1]}"
    when "includes only", "limited to"
      operands = operands2rubyvalue(operator, op_args, context_type)
      clause = "(#{operands[0]} - #{operands[1]}) == []"
    when "like", "not like", "starts with", "ends with", "includes"
      operands = operands2rubyvalue(operator, op_args, context_type)
      operands[1] =
        case operator
        when "starts with"
          "/^" + re_escape(operands[1].to_s) + "/"
        when "ends with"
          "/" + re_escape(operands[1].to_s) + "$/"
        else
          "/" + re_escape(operands[1].to_s) + "/"
        end
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
      clause = "!(" + clause + ")" if operator == "not like"
    when "regular expression matches", "regular expression does not match"
      operands = operands2rubyvalue(operator, op_args, context_type)

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
      clause = "(" + op_args.collect { |operand| _to_ruby(operand, context_type, tz) }.join(" #{normalize_ruby_operator(operator)} ") + ")"
    when "not", "!"
      clause = normalize_ruby_operator(operator) + "(" + _to_ruby(op_args, context_type, tz) + ")"
    when "is null", "is not null", "is empty", "is not empty"
      operands = operands2rubyvalue(operator, op_args, context_type)
      clause = operands.join(" #{normalize_ruby_operator(operator)} ")
    when "contains"
      op_args["tag"] ||= col_name
      operands = if context_type != "hash"
                   target = parse_field_or_tag(op_args["tag"])
                   ["<exist ref=#{target.model.to_s.downcase}>#{target.tag_path_with(op_args["value"])}</exist>"]
                 elsif context_type == "hash"
                   # This is only for supporting reporting "display filters"
                   # In the report object the tag value is actually the description and not the raw tag name.
                   # So we have to trick it by replacing the value with the description.
                   description = MiqExpression.get_entry_details(op_args["tag"]).inject("") do |s, t|
                     break(t.first) if t.last == op_args["value"]
                     s
                   end
                   val = op_args["tag"].split(".").last.split("-").join(".")
                   fld = "<value type=string>#{val}</value>"
                   [fld, quote(description, "string")]
                 end
      clause = operands.join(" #{normalize_operator(operator)} ")
    when "find"
      # FIND Vm.users-name = 'Administrator' CHECKALL Vm.users-enabled = 1
      check = nil
      check = "checkall" if op_args.include?("checkall")
      check = "checkany" if op_args.include?("checkany")
      if op_args.include?("checkcount")
        check = "checkcount"
        op = op_args[check].keys.first
        op_args[check][op]["field"] = "<count>"
      end
      raise _("expression malformed,  must contain one of 'checkall', 'checkany', 'checkcount'") unless check
      check =~ /^check(.*)$/
      mode = $1.downcase
      clause = "<find><search>" + _to_ruby(op_args["search"], context_type, tz) + "</search>" \
               "<check mode=#{mode}>" + _to_ruby(op_args[check], context_type, tz) + "</check></find>"
    when "key exists"
      clause, = operands2rubyvalue(operator, op_args, context_type)
    when "value exists"
      clause, = operands2rubyvalue(operator, op_args, context_type)
    when "is"
      col_ruby, _value = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      col_type = parse_field_or_tag(col_name)&.column_type
      value = op_args["value"]
      clause = if col_type == :date && !RelativeDatetime.relative?(value)
                 ruby_for_date_compare(col_ruby, col_type, tz, "==", value)
               else
                 ruby_for_date_compare(col_ruby, col_type, tz, ">=", value, "<=", value)
               end
    when "from"
      col_ruby, _value = operands2rubyvalue(operator, {"field" => col_name}, context_type)
      col_type = parse_field_or_tag(col_name)&.column_type

      start_val, end_val = op_args["value"]
      clause = ruby_for_date_compare(col_ruby, col_type, tz, ">=", start_val, "<=", end_val)
    else
      raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator.upcase}
    end

    # puts "clause: #{clause}"
    clause
  end

  def to_sql(tz = nil)
    tz ||= "UTC"
    pexp, attrs = preprocess_for_sql(exp.deep_clone)
    sql = to_arel(pexp, tz).to_sql if pexp.present?
    incl = includes_for_sql unless sql.blank?
    [sql, incl, attrs]
  end

  def preprocess_for_sql(exp, attrs = nil)
    exp.delete(:token)
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
      if sql_supports_atom?(exp)
        # if field type is Integer and value is String representing size in units (like "2.megabytes") than convert
        # this string to correct number using sub_type mappong defined in db/fixtures/miq_report_formats.yml:sub_types_by_column:
        convert_size_in_units_to_integer(exp) if %w[= != <= >= > <].include?(operator)
      else
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
      if exp[operator].key?("tag")
        Tag.parse(exp[operator]["tag"]).reflection_supported_by_sql?
      elsif exp[operator].key?("field")
        Field.parse(exp[operator]["field"]).attribute_supported_by_sql?
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
    when "includes any", "includes all", "includes only"
      # Support this only from the main model (for now)
      if exp[operator].keys.include?("field") && exp[operator]["field"].split(".").length == 1
        model, field = exp[operator]["field"].split("-")
        method = "miq_expression_#{operator.downcase.tr(' ', '_')}_#{field}_arel"
        return model.constantize.respond_to?(method)
      else
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
    return false unless attribute_supported_by_sql?(field)

    # => false if excluded by special case defined in preprocess options
    return false if field_excluded_by_preprocess_options?(field)

    true
  end

  def attribute_supported_by_sql?(field)
    return false unless col_details[field]
    col_details[field][:sql_support]
  end

  def field_excluded_by_preprocess_options?(field)
    col_details[field][:excluded_by_preprocess_options]
  end

  def col_details
    @col_details ||= self.class.get_cols_from_expression(exp, preprocess_options)
  end

  def includes_for_sql
    col_details.values.each_with_object({}) { |v, result| result.deep_merge!(v[:include]) }
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
    result ||= {:data_type => nil, :sql_support => true, :excluded_by_preprocess_options => false, :tag => false, :include => {}}

    f = parse_field_or_tag(field)
    unless f.kind_of?(MiqExpression::Field)
      result[:sql_support] = true
      result[:data_type] = f.column_type
      result[:tag] = true if f.kind_of?(MiqExpression::Tag)
      return result
    end

    result[:include] = f.includes

    if f.column
      result[:data_type] = f.column_type
      result[:format_sub_type] = f.sub_type
      result[:sql_support] = f.attribute_supported_by_sql?
      result[:excluded_by_preprocess_options] = f.exclude_col_by_preprocess_options?(options)
    end
    result
  rescue ArgumentError
    result[:sql_support] = false
    result
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
    operators.each do |k|
      if %w(and or).include?(k.to_s.downcase) # and/or atom is an array of atoms
        exp[k].each do |atom|
          evaluate_atoms(atom, obj)
        end
      elsif %w(not !).include?(k.to_s.downcase) # not atom is a hash expression
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
      MiqExpression.get_entry_details(ops["tag"]).each do |t|
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
          col_type = parse_field_or_tag(ops["field"])&.column_type || "string"
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
      friendly = tables.split(".").collect do |t|
        if t.downcase == "managed"
          val_is_a_tag = true
          "#{Tenant.root_tenant.name} Tags"
        elsif t.downcase == "user_tag"
          "My Tags"
        elsif first
          first = nil
          next unless options[:include_model] == true
          Dictionary.gettext(t, :type => :model, :notfound => :titleize)
        else
          Dictionary.gettext(t, :type => :table, :notfound => :titleize)
        end
      end.compact
      ret = friendly.join(".")
      ret << " : " unless ret.blank? || col.blank?
    end
    if val_is_a_tag
      if col
        classification = options[:classification] || Classification.lookup_by_name(col)
        ret << (classification ? classification.description : col)
      end
    else
      model = tables.blank? ? nil : tables.split(".").last.singularize.camelize
      dict_col = model.nil? ? col : [model, col].join(".")
      column_human = if col
                       if col.starts_with?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)
                         CustomAttributeMixin.to_human(col)
                       else
                         Dictionary.gettext(dict_col, :type => :column, :notfound => :titleize)
                       end
                     end
      ret << column_human if col
    end
    ret = " #{ret}" unless ret.include?(":")
    ret
  end

  def self.quote_by(operator, value, column_type = nil)
    if UNQUOTABLE_OPERATORS.map(&:downcase).include?(operator)
      value
    else
      quote(value, column_type.to_s)
    end
  end

  def self.operands2rubyvalue(operator, ops, context_type)
    if ops["field"]
      if ops["field"] == "<count>"
        ["<count>", quote(ops["value"], "integer")]
      else
        target = parse_field_or_tag(ops["field"])
        col_type = target&.column_type || "string"

        [if context_type == "hash"
           "<value type=#{col_type}>#{ops["field"].split(".").last.split("-").join(".")}</value>"
         else
           "<value ref=#{target.model.to_s.downcase}, type=#{col_type}>#{target.tag_path_with}</value>"
         end, quote_by(operator, ops["value"], col_type)]
      end
    elsif ops["count"]
      target = parse_field_or_tag(ops["count"])
      ["<count ref=#{target.model.to_s.downcase}>#{target.tag_path_with}</count>", quote(ops["value"], target.column_type)]
    elsif ops["regkey"]
      if operator == "key exists"
        ["<registry key_exists=1, type=boolean>#{ops["regkey"].strip}</registry>  == 'true'", nil]
      elsif operator == "value exists"
        ["<registry value_exists=1, type=boolean>#{ops["regkey"].strip} : #{ops["regval"]}</registry>  == 'true'", nil]
      else
        ["<registry>#{ops["regkey"].strip} : #{ops["regval"]}</registry>", quote_by(operator, ops["value"], "string")]
      end
    end
  end

  def self.quote(val, typ)
    if Field.is_field?(val)
      target = parse_field_or_tag(val)
      value = target.tag_path_with
      col_type = target&.column_type || "string"

      reference_attribute = target ? "ref=#{target.model.to_s.downcase}, " : " "
      return "<value #{reference_attribute}type=#{col_type}>#{value}</value>"
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
      v_arr = Array.wrap(val).flat_map do |v|
        if v.kind_of?(String)
          v = begin
                eval(v)
              rescue
                nil
              end
        end
        v.kind_of?(Range) ? v.to_a : v
      end.compact.uniq.sort
      "[#{v_arr.join(",")}]"
    when "string_set"
      val = val.split(",") if val.kind_of?(String)
      v_arr = Array.wrap(val).flat_map { |v| "'#{v.to_s.strip}'" }.uniq.sort
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
        val, sfx = $1, $2
        if sfx.ends_with?("bytes") && FORMAT_BYTE_SUFFIXES.key?(sfx.to_sym)
          "#{val} #{FORMAT_BYTE_SUFFIXES[sfx.to_sym]}"
        else
          "#{val} #{sfx.titleize}"
        end
      else
        val
      end
    when "string", "date", "datetime"
      "\"#{val}\""
    else
      quote(val, typ)
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

  def self.escape_virtual_custom_attribute(attribute)
    if attribute.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)
      uri_parser = URI::RFC2396_Parser.new
      [uri_parser.escape(attribute, /[^A-Za-z0-9:\-_]/), true]
    else
      [attribute, false]
    end
  end

  def self.normalize_ruby_operator(str)
    case str
    when "equal", "="
      "=="
    when "not"
      "!"
    when "like", "not like", "starts with", "ends with", "includes", "regular expression matches"
      "=~"
    when "regular expression does not match"
      "!~"
    when "is null", "is empty"
      "=="
    when "is not null", "is not empty"
      "!="
    when "before"
      "<"
    when "after"
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

  def self.base_tables
    BASE_TABLES
  end

  def self.model_details(model, opts = {:typ => "all", :include_model => true, :include_tags => false, :include_my_tags => false, :include_id_columns => false})
    @classifications = nil
    model = model.to_s

    opts = {:typ => "all", :include_model => true}.merge(opts)
    if opts[:typ] == "tag"
      tags_for_model = if TAG_CLASSES.include?(model)
                         tag_details(model, opts)
                       else
                         []
                       end
      result = []
      TAG_CLASSES.invert.each do |name, tc|
        next if tc.constantize.base_class == model.constantize.base_class
        path = [model, name].join(".")
        result.concat(tag_details(path, opts))
      end
      @classifications = nil
      return tags_for_model.concat(result.sort! { |a, b| a.to_s <=> b.to_s })
    end

    relats = get_relats(model)

    result = []
    unless opts[:typ] == "count" || opts[:typ] == "find"
      @column_cache ||= {}
      key = "#{model}_#{opts[:interval]}_#{opts[:include_model] || false}"
      @column_cache[key] = nil if model == "ChargebackVm"
      @column_cache[key] ||= get_column_details(relats[:columns], model, model, opts).sort! { |a, b| a.to_s <=> b.to_s }
      result.concat(@column_cache[key])

      unless opts[:disallow_loading_virtual_custom_attributes]
        custom_details = _custom_details_for(model, opts)
        result.concat(custom_details.sort_by(&:to_s)) unless custom_details.empty?
      end
      result.concat(tag_details(model, opts)) if opts[:include_tags] == true && TAG_CLASSES.include?(model)
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
      custom_detail_column = [options[:model_for_column] || model, CustomAttributeMixin.column_name(custom_key)].join("-")
      custom_detail_name = CustomAttributeMixin.to_human(custom_key)

      if options[:include_model]
        model_name = Dictionary.gettext(model, :type => :model, :notfound => :titleize)
        custom_detail_name = [model_name, custom_detail_name].join(" : ")
      end
      custom_attributes_details.push([custom_detail_name, custom_detail_column])
    end

    custom_attributes_details
  end

  def self._model_details(relats, opts)
    result = []
    relats[:reflections].each do |_assoc, ref|
      parent = ref[:parent]
      case opts[:typ]
      when "count"
        result.push(get_table_details(parent[:class_path], parent[:assoc_path])) if parent[:multivalue]
      when "find"
        result.concat(get_column_details(ref[:columns], parent[:class_path], parent[:assoc_path], opts)) if parent[:multivalue]
      else
        result.concat(get_column_details(ref[:columns], parent[:class_path], parent[:assoc_path], opts))
        if opts[:include_tags] == true && TAG_CLASSES.include?(parent[:assoc_class])
          result.concat(tag_details(parent[:class_path], opts))
        end
      end

      result.concat(_model_details(ref, opts))
    end
    result
  end

  def self.tag_details(path, opts)
    result = []
    if opts[:no_cache]
      @classifications = nil
    end
    @classifications ||= categories
    @classifications.each do |name, cat|
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
    @model_relats[model] = nil if model == "ChargebackVm"
    @model_relats[model] ||= build_relats(model)
  end

  def self.miq_adv_search_lists(model, what, extra_options = {})
    @miq_adv_search_lists ||= {}
    @miq_adv_search_lists[model.to_s] ||= {}
    options = {:include_model => true}.merge(extra_options)

    case what.to_sym
    when :exp_available_fields then
      @miq_adv_search_lists[model.to_s][:exp_available_fields] ||= MiqExpression.model_details(model, options.merge(:typ => "field", :disallow_loading_virtual_custom_attributes => false))
    when :exp_available_counts then @miq_adv_search_lists[model.to_s][:exp_available_counts] ||= MiqExpression.model_details(model, options.merge(:typ => "count"))
    when :exp_available_finds  then @miq_adv_search_lists[model.to_s][:exp_available_finds]  ||= MiqExpression.model_details(model, options.merge(:typ => "find"))
    end
  end

  def self.reporting_available_fields(model, interval = nil)
    if model.to_s == "VimPerformanceTrend"
      VimPerformanceTrend.trend_model_details(interval.to_s)
    elsif model.ends_with?("Performance")
      model_details(model, :include_model => false, :include_tags => true, :interval => interval)
    elsif Chargeback.db_is_chargeback?(model)
      cb_model = Chargeback.report_cb_model(model)
      model.constantize.try(:refresh_dynamic_metric_columns)
      md = model_details(model, :include_model => false, :include_tags => true).select do |c|
        allowed_suffixes = Chargeback::ALLOWED_FIELD_SUFFIXES
        allowed_suffixes += Metering::ALLOWED_FIELD_SUFFIXES if model.starts_with?('Metering')
        c.last.ends_with?(*allowed_suffixes)
      end
      td = if TAG_CLASSES.include?(cb_model)
             tag_details(model, {})
           else
             []
           end
      md + td + _custom_details_for(cb_model, :model_for_column => model)
    else
      model_details(model, :include_model => false, :include_tags => true)
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

    model.reflections_with_virtual.each do |assoc, ref|
      next unless INCLUDE_TABLES.include?(assoc.to_s.pluralize)
      next if     assoc.to_s.pluralize == "event_logs" && parent[:root] == "Host" && !proto?
      next if     assoc.to_s.pluralize == "processes" && parent[:root] == "Host" # Process data not available yet for Host

      next if ref.macro == :belongs_to && model.name != parent[:root]

      # REMOVE ME: workaround to temporarily exclude certain models from the relationships
      next if EXCLUDE_FROM_RELATS[model.name]&.include?(assoc.to_s)

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
      next if seen.include?(seen_key) ||
              assoc_class == parent[:root] ||
              parent[:assoc_path].include?(assoc.to_s) ||
              parent[:assoc_path].include?(assoc.to_s.singularize) ||
              parent[:direction] == :up ||
              parent[:multivalue]
      seen.push(seen_key)
      result[:reflections][assoc] = build_relats(assoc_class, new_parent, seen)
    end
    result
  end

  def self.get_table_details(class_path, assoc_path)
    [value2human(class_path), assoc_path]
  end

  def self.get_column_details(column_names, class_path, assoc_path, opts)
    include_model = opts[:include_model]
    base_model = class_path.split(".").first

    excludes  = EXCLUDE_COLUMNS
    excludes += EXCLUDE_ID_COLUMNS unless opts[:include_id_columns]

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
    when base_model.starts_with?("Container")
      excludes += ["^.*derived_host_count_off$", "^.*derived_host_count_on$", "^.*derived_vm_count_off$", "^.*derived_vm_count_on$", "^.*derived_storage.*$"]
    end

    column_names.collect do |c|
      # check for direct match first
      next if excludes.include?(c) && !EXCLUDE_EXCEPTIONS.include?(c)

      # check for regexp match if no direct match
      col = c
      unless EXCLUDE_EXCEPTIONS.include?(c)
        excludes.each do |excl|
          if c.match(excl)
            col = nil
            break
          end
        end
      end
      next unless col
      field_class_path = "#{class_path}-#{col}"
      field_assoc_path = "#{assoc_path}-#{col}"
      [value2human(field_class_path, :include_model => include_model), field_assoc_path]
    end.compact
  end

  def self.get_col_operators(field)
    col_type =
      if field == :count || field == :regkey
        field
      else
        parse_field_or_tag(field.to_s)&.column_type || :string
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

  STYLE_OPERATORS_EXCLUDES = config[:style_operators_excludes]
  def self.get_col_style_operators(field)
    get_col_operators(field) - STYLE_OPERATORS_EXCLUDES
  end

  def self.get_entry_details(field)
    ns = field.split("-").first.split(".").last

    if ns == "managed"
      cat = field.split("-").last
      catobj = Classification.lookup_by_name(cat)
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
      return false if send((dt == :float ? :numeric? : :integer?), value)

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

      values = value.kind_of?(String) ? value.lines : Array.wrap(value)
      return _("No Date/Time value specified") if values.empty? || values.include?(nil)
      return _("Two Date/Time values must be specified") if operator.downcase == "from" && values.length < 2

      values_converted = values.collect do |v|
        return _("Date/Time value must not be blank") if value.blank?
        v_cvt = begin
                  RelativeDatetime.normalize(v, "UTC")
                rescue
                  nil
                end
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

  def self.categories
    classifications = Classification.in_my_region.hash_all_by_type_and_name(:show => true)
    categories_with_entries = classifications.reject { |_k, v| !v.key?(:entry) }
    categories_with_entries.each_with_object({}) do |(name, hash), categories|
      categories[name] = hash[:category]
    end
  end

  def self.model_class(model)
    # TODO: the temporary cache should be removed after widget refactoring
    @model_class ||= Hash.new do |h, m|
      h[m] = if m.kind_of?(Class)
               m
             else
               begin
                 m.to_s.singularize.camelize.constantize
               rescue
                 nil
               end
             end
    end
    @model_class[model]
  end

  def self.integer?(n)
    n = n.to_s
    n2 = n.delete(',') # strip out commas
    begin
      Integer(n2)
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

  def self.numeric?(n)
    n = n.to_s
    n2 = n.delete(',') # strip out commas
    begin
      Float(n2)
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
    _quick_search?(exp)
  end

  def quick_search?
    self.class._quick_search?(exp) # Pass the exp hash
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

  def self.create_field(model, associations, field_name)
    model = model_class(model)
    Field.new(model, associations, field_name)
  end

  def self.parse_field_or_tag(str)
    # managed.location, Model.x.y.managed-location
    MiqExpression::Field.parse(str) || MiqExpression::CountField.parse(str) || MiqExpression::Tag.parse(str)
  end

  def fields(expression = exp)
    case expression
    when Array
      expression.flat_map { |x| fields(x) }
    when Hash
      return [] if expression.empty?

      if (val = expression["field"] || expression["count"] || expression["tag"])
        ret = []
        tg = self.class.parse_field_or_tag(val)
        ret << tg if tg
        tg = self.class.parse_field_or_tag(expression["value"].to_s)
        ret << tg if tg
        ret
      else
        fields(expression.values)
      end
    end
  end

  private

  def convert_size_in_units_to_integer(exp)
    return if (column_details = col_details[exp.values.first["field"]]).nil?
    # attempt to do conversion only if db type of column is integer and value to compare to is String
    return unless column_details[:data_type] == :integer && (value = exp.values.first["value"]).class == String

    sub_type = column_details[:format_sub_type]

    return if %i[mhz_avg hours kbps kbps_precision_2 mhz elapsed_time].include?(sub_type)

    case sub_type
    when :bytes
      exp.values.first["value"] = value.to_i_with_method
    when :kilobytes
      exp.values.first["value"] = value.to_i_with_method / 1_024
    when :megabytes, :megabytes_precision_2
      exp.values.first["value"] = value.to_i_with_method / 1_048_576
    else
      _log.warn("No subtype defined for column #{exp.values.first["field"]} in 'miq_report_formats.yml'")
    end
  end

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
  private_class_method :ruby_for_date_compare

  def to_arel(exp, tz)
    operator = exp.keys.first
    field = Field.parse(exp[operator]["field"]) if exp[operator].kind_of?(Hash) && exp[operator]["field"]
    arel_attribute = field&.arel_attribute
    if exp[operator].kind_of?(Hash) && exp[operator]["value"] && Field.is_field?(exp[operator]["value"])
      field_value = Field.parse(exp[operator]["value"])
      parsed_value = field_value.arel_attribute
    elsif exp[operator].kind_of?(Hash)
      parsed_value = exp[operator]["value"]
    end
    case operator.downcase
    when "equal", "="
      arel_attribute.eq(parsed_value)
    when ">"
      arel_attribute.gt(parsed_value)
    when "after"
      value = RelativeDatetime.normalize(parsed_value, tz, "end", field.date?)
      arel_attribute.gt(value)
    when ">="
      arel_attribute.gteq(parsed_value)
    when "<"
      arel_attribute.lt(parsed_value)
    when "before"
      value = RelativeDatetime.normalize(parsed_value, tz, "beginning", field.date?)
      arel_attribute.lt(value)
    when "<="
      arel_attribute.lteq(parsed_value)
    when "!="
      arel_attribute.not_eq(parsed_value)
    when "like", "includes"
      escape = nil
      case_sensitive = true
      arel_attribute.matches("%#{parsed_value}%", escape, case_sensitive)
    when "includes all", "includes any", "includes only"
      method = "miq_expression_"
      method << "#{operator.downcase.tr(' ', '_')}_"
      method << "#{field.column}_arel"
      field.model.send(method, parsed_value)
    when "starts with"
      escape = nil
      case_sensitive = true
      arel_attribute.matches("#{parsed_value}%", escape, case_sensitive)
    when "ends with"
      escape = nil
      case_sensitive = true
      arel_attribute.matches("%#{parsed_value}", escape, case_sensitive)
    when "not like"
      escape = nil
      case_sensitive = true
      arel_attribute.does_not_match("%#{parsed_value}%", escape, case_sensitive)
    when "and"
      operands = exp[operator].each_with_object([]) do |operand, result|
        next if operand.blank?
        arel = to_arel(operand, tz)
        next if arel.blank?
        result << arel
      end
      Arel::Nodes::Grouping.new(Arel::Nodes::And.new(operands))
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
      arel_attribute.eq(nil)
    when "is not null"
      arel_attribute.not_eq(nil)
    when "is empty"
      arel = arel_attribute.eq(nil)
      arel = arel.or(arel_attribute.eq("")) if field.string?
      arel
    when "is not empty"
      arel = arel_attribute.not_eq(nil)
      arel = arel.and(arel_attribute.not_eq("")) if field.string?
      arel
    when "contains"
      # Only support for tags of the main model
      if exp[operator].key?("tag")
        tag = Tag.parse(exp[operator]["tag"])
        ids = tag.target.find_tagged_with(:any => parsed_value, :ns => tag.namespace).pluck(:id)
        subquery_for_contains(tag, tag.arel_attribute.in(ids))
      else
        subquery_for_contains(field, arel_attribute.eq(parsed_value))
      end
    when "is"
      value = parsed_value
      start_val = RelativeDatetime.normalize(value, tz, "beginning", field.date?)
      end_val = RelativeDatetime.normalize(value, tz, "end", field.date?)

      if !field.date? || RelativeDatetime.relative?(value)
        arel_attribute.between(start_val..end_val)
      else
        arel_attribute.eq(start_val)
      end
    when "from"
      start_val, end_val = parsed_value
      start_val = RelativeDatetime.normalize(start_val, tz, "beginning", field.date?)
      end_val   = RelativeDatetime.normalize(end_val, tz, "end", field.date?)
      arel_attribute.between(start_val..end_val)
    else
      raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator}
    end
  end

  def subquery_for_contains(field, limiter_query)
    return limiter_query if field.reflections.empty?

    # Remove the default scopes via `base_class`. The scope is already in the main query and not needed in the subquery
    main_model = field.model.base_class
    primary_attribute = main_model.arel_table[main_model.primary_key]

    includes_associations = field.reflections.reverse.inject({}) { |i, k| {k.name => i} }
    relation_query = main_model.select(primary_attribute)
                               .joins(includes_associations)
                               .where(limiter_query)

    conn = main_model.connection
    sql  = conn.unprepared_statement { conn.to_sql(relation_query.arel) }
    Arel::Nodes::In.new(primary_attribute, Arel::Nodes::SqlLiteral.new(sql))
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
  private_class_method :determine_relat_path

  def each_atom(component, &block)
    operator = component.keys.first

    case operator.downcase
    when "and", "or"
      component[operator].each { |sub_component| each_atom(sub_component, &block) }
    when "not", "!"
      each_atom(component[operator], &block)
    when "find"
      component[operator].each { |_operator, operands| each_atom(operands, &block) }
    else
      yield(component[operator])
    end
  end
end # class MiqExpression
