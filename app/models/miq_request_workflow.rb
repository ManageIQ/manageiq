require 'enumerator'
require 'miq-hash_struct'

class MiqRequestWorkflow
  include Vmdb::Logging
  include_concern "DialogFieldValidation"

  # We rely on MiqRequestWorkflow's descendants to be comprehensive
  singleton_class.send(:prepend, DescendantLoader::ArDescendantsWithLoader)

  attr_accessor :dialogs, :requester, :values, :last_vm_id

  def self.automate_dialog_request
    nil
  end

  def self.default_dialog_file
    nil
  end

  def self.default_pre_dialog_file
    nil
  end

  def self.encrypted_options_fields
    []
  end

  def self.encrypted_options_field_regs
    encrypted_options_fields.map { |f| /\[:#{f}\]/ }
  end

  def self.all_encrypted_options_fields
    descendants.flat_map(&:encrypted_options_fields).uniq
  end

  def self.update_requester_from_parameters(data, user)
    return user if data[:user_name].blank?
    new_user = User.lookup_by_identity(data[:user_name])

    unless new_user
      _log.error("requested not changed to <#{data[:user_name]}> due to a lookup failure")
      raise ActiveRecord::RecordNotFound
    end

    _log.warn("requested changed to <#{new_user.userid}>")
    new_user
  end

  def initialize(values, requester, options = {})
    instance_var_init(values, requester, options)

    unless options[:skip_dialog_load] == true
      # If this is the first time we are called the values hash will be empty
      # Also skip if we are being called from a web-service
      if @dialogs.nil?
        @dialogs = get_dialogs
        normalize_numeric_fields
      else
        @running_pre_dialog = true if options[:use_pre_dialog] != false
      end
    end

    unless options[:skip_dialog_load] == true
      set_default_values
      update_field_visibility
    end
  end

  def instance_var_init(values, requester, options)
    @values       = values
    @filters      = {}
    @requester    = requester.kind_of?(User) ? requester : User.lookup_by_identity(requester)
    group_description = values[:requester_group]
    if group_description && group_description != @requester.miq_group_description
      @requester = @requester.clone
      @requester.current_group_by_description = group_description
    end
    @values.merge!(options) unless options.blank?
  end

  # Helper method when not using workflow
  def make_request(request, values, requester = nil, auto_approve = false)
    return false unless validate(values)
    password_helper(values, true)
    # Ensure that tags selected in the pre-dialog get applied to the request
    values[:vm_tags] = (values[:vm_tags].to_miq_a + @values[:pre_dialog_vm_tags]).uniq if @values.try(:[], :pre_dialog_vm_tags).present?

    set_request_values(values)
    if request
      MiqRequest.update_request(request, values, @requester)
    else
      req = request_class.new(:options => values, :requester => @requester, :request_type => request_type.to_s)
      return req unless req.valid? # TODO: CatalogController#atomic_req_submit is the only one that enumerates over the errors
      values[:__request_type__] = request_type.to_s.presence # Pass this along to MiqRequest#create_request
      request_class.create_request(values, @requester, auto_approve)
    end
  end

  def init_from_dialog(init_values)
    @dialogs[:dialogs].keys.each do |dialog_name|
      get_all_fields(dialog_name).each_pair do |field_name, field_values|
        next unless init_values[field_name].nil?
        next if field_values[:display] == :ignore

        if !field_values[:default].nil?
          val = field_values[:default]
        end

        if field_values[:values]
          if field_values[:values].kind_of?(Hash)
            # Save [value, description], skip for timezones array
            init_values[field_name] = [val, field_values[:values][val]]
          else
            field_values[:values].each do |tz|
              if tz[1].to_i_with_method == val.to_i_with_method
                # Save [value, description] for timezones array
                init_values[field_name] = [val, tz[0]]
              end
            end
          end
        else
          # Set to default value
          init_values[field_name] = val
        end
      end
    end
  end

  def validate(values)
    # => Input - A hash keyed by field name with entered values
    # => Output - true || false
    #
    # Update @dialogs adding error keys to fields that don't validate
    valid = true

    get_all_dialogs(false).each do |d, dlg|
      # Check if the entire dialog is ignored or disabled and check while processing the fields
      dialog_disabled = !dialog_active?(d, dlg, values)

      get_all_fields(d, false).each do |f, fld|
        fld[:error] = nil

        # Check the disabled flag here so we reset the "error" value on each field
        next if dialog_disabled || fld[:display] == :hide
        value = fld[:data_type] =~ /array_/ ? values[f] : get_value(values[f])

        if fld[:required] == true
          # If :required_method is defined let it determine if the field is value
          if fld[:required_method].nil?
            default_require_method = "default_require_#{f}".to_sym
            if self.respond_to?(default_require_method)
              fld[:error] = send(default_require_method, f, values, dlg, fld, value)
              unless fld[:error].nil?
                valid = false
                next
              end
            else
              if value.blank?
                fld[:error] = "#{required_description(dlg, fld)} is required"
                valid = false
                next
              end
            end
          else
            Array.wrap(fld[:required_method]).each do |method|
              fld[:error] = send(method, f, values, dlg, fld, value)
              # Bail out early if we see an error
              break unless fld[:error].nil?
            end

            unless fld[:error].nil?
              valid = false
              next
            end
          end
        end

        if fld[:validation_method] && respond_to?(fld[:validation_method])
          if (fld[:error] = send(fld[:validation_method], f, values, dlg, fld, value))
            valid = false
            next
          end
        end

        next if value.blank?

        msg = "'#{fld[:description]}' in dialog #{dlg[:description]} must be of type #{fld[:data_type]}"
        validate_data_types(value, fld, msg, valid)
      end
    end

    valid
  end

  def validate_data_types(value, fld, msg, valid)
    case fld[:data_type]
    when :integer
      unless is_integer?(value)
        fld[:error] = msg
        valid = false
      end
    when :float
      unless is_numeric?(value)
        fld[:error] = msg
        valid = false
      end
    when :boolean
      # TODO: do we need validation for boolean
    when :button
      # Ignore
    when :array_integer
      unless value.kind_of?(Array)
        fld[:error] = msg
        valid = false
      end
    else
      data_type = Object.const_get(fld[:data_type].to_s.camelize)
      unless value.kind_of?(data_type)
        fld[:error] = msg
        valid = false
      end
    end
    [valid, fld]
  end

  def get_dialog_order
    @dialogs[:dialog_order]
  end

  def get_buttons
    @dialogs[:buttons] || [:submit, :cancel]
  end

  def provisioning_tab_list
    dialog_names = @dialogs[:dialog_order].collect(&:to_s)
    dialog_descriptions = dialog_names.collect do |dialog_name|
      @dialogs.fetch_path(:dialogs, dialog_name.to_sym, :description)
    end
    dialog_display = dialog_names.collect do |dialog_name|
      @dialogs.fetch_path(:dialogs, dialog_name.to_sym, :display)
    end

    tab_list = []
    dialog_names.each_with_index do |dialog_name, index|
      next if dialog_display[index] == :hide || dialog_display[index] == :ignore

      tab_list << {
        :name        => dialog_name,
        :description => dialog_descriptions[index]
      }
    end

    tab_list
  end

  def get_all_dialogs(refresh_values = true)
    @dialogs[:dialogs].each_key { |d| get_dialog(d, refresh_values) }
    @dialogs[:dialogs]
  end

  def get_dialog(dialog_name, refresh_values = true)
    dialog = @dialogs.fetch_path(:dialogs, dialog_name.to_sym)
    return {} unless dialog

    get_all_fields(dialog_name, refresh_values)
    dialog
  end

  def get_all_fields(dialog_name, refresh_values = true)
    dialog = @dialogs.fetch_path(:dialogs, dialog_name.to_sym)
    return {} unless dialog

    dialog[:fields].each_key { |f| get_field(f, dialog_name, refresh_values) }
    dialog[:fields]
  end

  def get_field(field_name, dialog_name = nil, refresh_values = true)
    field_name = field_name.to_sym
    dialog_name = find_dialog_from_field_name(field_name) if dialog_name.nil?
    field = @dialogs.fetch_path(:dialogs, dialog_name.to_sym, :fields, field_name)
    return {} unless field

    if field.key?(:values_from) && refresh_values
      options = field[:values_from][:options] || {}
      options[:prov_field_name] = field_name
      field[:values] = send(field[:values_from][:method], options)

      # Reset then currently selected item if it no longer appears in the available values
      if field[:values].kind_of?(Hash)
        if field[:values].length == 1
          unless field[:auto_select_single] == false
            @values[field_name] = field[:values].to_a.first
          end
        else
          currently_selected = get_value(@values[field_name])
          unless currently_selected.nil? || field[:values].key?(currently_selected)
            @values[field_name] = [nil, nil]
          end
        end
      end
    end
    field
  end

  # TODO: Return list in defined ordered
  def dialogs
    @dialogs[:dialogs].each_pair { |n, d| yield(n, d) }
  end

  def fields(dialog = nil)
    dialog = [*dialog] unless dialog.nil?
    @dialogs[:dialogs].each_pair do |dn, d|
      next unless dialog.blank? || dialog.include?(dn)
      d[:fields].each_pair do |fn, f|
        yield(fn, f, dn, d)
      end
    end
  end

  def normalize_numeric_fields
    fields do |_fn, f, _dn, _d|
      if f[:data_type] == :integer
        f[:default] = f[:default].to_i_with_method unless f[:default].blank?
        unless f[:values].blank?
          keys = f[:values].keys.dup
          keys.each { |k| f[:values][k.to_i_with_method] = f[:values].delete(k) }
        end
      end
    end
  end

  # Helper method to write message to the rails log (production.log) for debugging
  def rails_logger(_name, _start)
    # Rails.logger.warn("#{name} #{start.zero? ? 'start' : 'end'}")
  end

  def parse_ws_string(text_input, options = {})
    self.class.parse_ws_string(text_input, options)
  end

  def self.parse_ws_string(text_input, options = {})
    return parse_request_parameter_hash(text_input, options) if text_input.kind_of?(Hash)
    return {} unless text_input.kind_of?(String)

    deprecated_warn = "method: parse_ws_string, arg Type => String"
    solution = "arg should be a hash"
    MiqAeMethodService::Deprecation.deprecation_warning(deprecated_warn, solution)

    result = {}
    text_input.split('|').each do |value|
      next if value.blank?
      idx = value.index('=')
      next if idx.nil?
      key = options[:modify_key_name] == false ? value[0, idx].strip : value[0, idx].strip.downcase.to_sym
      result[key] = value[idx + 1..-1].strip
    end
    result
  end

  def self.parse_request_parameter_hash(parameter_hash, options = {})
    parameter_hash.each_with_object({}) do |param, hash|
      key, value = param
      key = key.strip.downcase.to_sym unless options[:modify_key_name] == false
      hash[key] = value
    end
  end

  def ws_tags(tag_string, parser = :parse_ws_string)
    # Tags are passed as category|value.  Example: cc|001|environment|test
    ws_tags = send(parser, tag_string)

    tags = allowed_tags.each_with_object({}) do |v, tags|
      tags[v[:name]] = v[:children].each_with_object({}) { |(k, v), tc| tc[v[:name]] = k }
    end

    ws_tags.collect { |cat, tag| tags.fetch_path(cat.to_s.downcase, tag.downcase) }.compact
  end

  # @param parser [:parse_ws_string|:parse_ws_string_v1]
  # @param additional_values [String] values of the form cc=001|environment=test
  def ws_values(additional_values, parser = :parse_ws_string, parser_options = {})
    parsed_values = send(parser, additional_values, parser_options)

    parsed_values.each_with_object({}) { |(k, v), ws_values| ws_values[k.to_sym] = v }
  end

  def parse_ws_string_v1(values, _options = {})
    na = []
    values.to_s.split("|").each_slice(2) do |k, v|
      next if v.nil?
      na << [k.strip, v.strip]
    end
    na
  end

  def find_dialog_from_field_name(field_name)
    @dialogs[:dialogs].each_key do |dialog_name|
      return dialog_name if @dialogs[:dialogs][dialog_name][:fields].key?(field_name.to_sym)
    end
    nil
  end

  def get_value(data)
    data.kind_of?(Array) ? data.first : data
  end

  def set_or_default_field_values(values)
    field_names = values.keys
    fields do |fn, f, _dn, _d|
      if field_names.include?(fn)
        if f.key?(:values)
          selected_key = nil
          if f[:values].key?(values[fn])
            selected_key = values[fn]
          elsif f.key?(:default) && f[:values].key?(f[:default])
            selected_key = f[:default]
          else
            unless f[:values].blank?
              sorted_values = f[:values].sort
              selected_key = sorted_values.first.first
            end
          end
          @values[fn] = [selected_key, f[:values][selected_key]] unless selected_key.nil?
        else
          @values[fn] = values[fn]
        end
      end
    end
  end

  def clear_field_values(field_names)
    fields do |fn, f, _dn, _d|
      if field_names.include?(fn)
        @values[fn] = f.key?(:values) ? [nil, nil] : nil
      end
    end
  end

  def set_value_from_list(fn, f, value, values = nil, partial_key = false)
    @values[fn] = [nil, nil]
    values = f[:values] if values.nil?
    unless value.nil?
      @values[fn] = values.to_a.detect do |v|
        if partial_key
          _log.warn("comparing [#{v[0]}] to [#{value}]")
          v[0].to_s.downcase.include?(value.to_s.downcase)
        else
          v.include?(value)
        end
      end
      if @values[fn].nil?
        _log.info("set_value_from_list did not matched an item") if partial_key
        @values[fn] = [nil, nil]
      else
        _log.info("set_value_from_list matched item value:[#{value}] to item:[#{@values[fn][0]}]") if partial_key
      end
    end
  end

  def show_dialog(dialog_name, show_flag, enabled_flag = nil)
    dialog = @dialogs.fetch_path(:dialogs, dialog_name.to_sym)
    unless dialog.nil?
      dialog[:display_init] = dialog[:display] if dialog[:display_init].nil?
      # If the initial dialog is not set to show then do not modify it here.
      return if dialog[:display_init] != :show

      dialog[:display] = show_flag
      @values["#{dialog_name}_enabled".to_sym] = [enabled_flag] unless enabled_flag.nil?
    end
  end

  def required_description(dlg, fld)
    "'#{dlg[:description]}/#{fld[:required_description] || fld[:description]}'"
  end

  def allowed_filters(options = {})
    model_name = options[:category]
    return @filters[model_name] unless @filters[model_name].nil?
    rails_logger("allowed_filters - #{model_name}", 0)
    @filters[model_name] = @requester.get_expressions(model_name).invert
    rails_logger("allowed_filters - #{model_name}", 1)
    @filters[model_name]
  end

  def dialog_active?(name, config, values)
    return false if config[:display] == :ignore

    enabled_field = "#{name}_enabled".to_sym
    # Check if the fields hash contains a <dialog_name>_enabled field
    enabled = get_value(values[enabled_field])
    return false if enabled == false || enabled == "disabled"
    true
  end

  def show_fields(display_flag, field_names, display_field = :display)
    fields do |fn, f, _dn, _d|
      if field_names.include?(fn)
        flag = f[:display_override].blank? ? display_flag : f[:display_override]
        f[display_field] = flag
      end
    end
  end

  def retrieve_ldap(_options = {})
    email = get_value(@values[:owner_email])
    unless email.blank?
      l = MiqLdap.new
      if l.bind_with_default == true
        raise _("No information returned for %{email}") % {:email => email} if (d = l.get_user_info(email)).nil?
        [:first_name, :last_name, :address, :city, :state, :zip, :country, :title, :company,
         :department, :office, :phone, :phone_mobile, :manager, :manager_mail, :manager_phone].each do |prop|
          @values["owner_#{prop}".to_sym] = d[prop].try(:dup)
        end
        @values[:sysprep_organization] = d[:company].try(:dup)
      end
    end
  end

  def default_schedule_time(options = {})
    # TODO: Added support for "default_from", like values_from, that gets called once after dialog creation
    # Update VM description
    fields do |fn, f, _dn, _d|
      if fn == :schedule_time
        f[:default] = Time.now + options[:offset].to_i_with_method if f[:default].nil?
        break
      end
    end
  end

  def values_less_then(options)
    results = options[:values].transform_keys(&:to_i_with_method)
    field, include_equals = options[:field], options[:include_equals]
    max_value = field.nil? ? options[:value].to_i_with_method : get_value(@values[field]).to_i_with_method
    return results if max_value <= 0
    results.reject { |k, _v| include_equals == true ? max_value < k : max_value <= k }
  end

  def tags
    vm_tags = @values[:vm_tags]
    return unless vm_tags.kind_of?(Array)

    vm_tags.each do |tag_id|
      tag = Classification.find(tag_id)
      yield(tag.name, tag.parent.name) # yield the tag's name and category
    end
  end

  def get_tags
    tag_string = ''
    tags do |tag, cat|
      tag_string << ':' unless tag_string.empty?
      tag_string << "#{cat}/#{tag}"
    end
    tag_string
  end

  def allowed_tags(options = {})
    return @tags unless @tags.nil?

    region_number = options.delete(:region_number)

    # TODO: Call allowed_tags properly from controller - it is currently hard-coded with no options passed
    field_options = @dialogs.fetch_path(:dialogs, :purpose, :fields, :vm_tags, :options)
    options = field_options unless field_options.nil?

    rails_logger('allowed_tags', 0)
    st = Time.now
    @tags = {}

    exclude_list  = options[:exclude].blank? ? [] : options[:exclude].collect(&:to_s)
    include_list  = options[:include].blank? ? [] : options[:include].collect(&:to_s)
    single_select = options[:single_select].blank? ? [] : options[:single_select].collect(&:to_s)

    cats = Classification.visible.writeable.managed
    cats = cats.in_region(region_number) if region_number
    cats.each do |t|
      next if exclude_list.include?(t.name)
      next unless include_list.blank? || include_list.include?(t.name)
      # Force passed tags to be single select
      single_value = single_select.include?(t.name) ? true : t.single_value?
      @tags[t.id] = {:name => t.name, :description => t.description, :single_value => single_value, :children => {}, :id => t.id}
    end

    ents = Classification.visible.writeable.parent_ids(@tags.keys).with_tag_name
    ents = ents.in_region(region_number) if region_number
    ents.each do |t|
      full_tag_name = "#{@tags[t.parent_id][:name]}/#{t.name}"
      next if exclude_list.include?(full_tag_name)
      @tags[t.parent_id][:children][t.id] = {:name => t.name, :description => t.description}
    end

    @tags.delete_if { |_k, v| v[:children].empty? }

    # Now sort the tags based on the order passed options.  All remaining tags not defined in the order
    # will be sorted by description and appended to the other sorted tags
    tag_results, tags_to_sort = [], []
    sort_order = options[:order].blank? ? [] : options[:order].collect(&:to_s)
    @tags.each do |_k, v|
      (idx = sort_order.index(v[:name])).nil? ? tags_to_sort << v : tag_results[idx] = v
    end

    tags_to_sort = tags_to_sort.sort_by { |a| a[:description] }
    @tags = tag_results.compact + tags_to_sort

    @tags.each do |tag|
      tag[:children] = if tag[:children].first.last[:name] =~ /^\d/
                         tag[:children].sort_by { |_k, v| v[:name].to_i }
                       else
                         tag[:children].sort_by { |_k, v| v[:description] }
                       end
    end

    rails_logger('allowed_tags', 1)
    _log.info("allowed_tags returned [#{@tags.length}] objects in [#{Time.now - st}] seconds")
    @tags
  end

  def allowed_tags_and_pre_tags
    pre_tags = @values[:pre_dialog_vm_tags].to_miq_a
    return allowed_tags if pre_tags.blank?

    tag_cats = allowed_tags.dup
    tag_cat_names = tag_cats.collect { |cat| cat[:name] }

    Classification.where(:id => pre_tags).each do |tag|
      parent = tag.parent
      next if tag_cat_names.include?(parent.name)

      new_cat = {:name => parent.name, :description => parent.description, :single_value => parent.single_value?, :children => {}, :id => parent.id}
      parent.children.each { |c| new_cat[:children][c.id] = {:name => c.name, :description => c.description} }
      tag_cats << new_cat
      tag_cat_names << new_cat[:name]
    end

    tag_cats
  end

  def tag_symbol
    :tag_ids
  end

  def build_ci_hash_struct(ci, props)
    nh = MiqHashStruct.new(:id => ci.id, :evm_object_class => ci.class.base_class.name.to_sym)
    props.each { |p| nh.send("#{p}=", ci.send(p)) }
    nh
  end

  def get_dialogs
    @values[:miq_request_dialog_name] ||= @values[:provision_dialog_name] || dialog_name_from_automate || self.class.default_dialog_file
    dp = @values[:miq_request_dialog_name] = File.basename(@values[:miq_request_dialog_name], ".rb")
    _log.info("Loading dialogs <#{dp}> for user <#{@requester.userid}>")
    d = MiqDialog.find_by("lower(name) = ? and dialog_type = ?", dp.downcase, self.class.base_model.name)
    if d.nil?
      raise MiqException::Error,
            "Dialog cannot be found.  Name:[%{name}]  Type:[%{type}]" % {:name => @values[:miq_request_dialog_name],
                                                                         :type => self.class.base_model.name}
    end
    d.content
  end

  def get_pre_dialogs
    pre_dialogs = nil
    pre_dialog_name = dialog_name_from_automate('get_pre_dialog_name')
    unless pre_dialog_name.blank?
      pre_dialog_name = File.basename(pre_dialog_name, ".rb")
      d = MiqDialog.find_by(:name => pre_dialog_name, :dialog_type => self.class.base_model.name)
      unless d.nil?
        _log.info("Loading pre-dialogs <#{pre_dialog_name}> for user <#{@requester.userid}>")
        pre_dialogs = d.content
      end
    end

    pre_dialogs
  end

  def dialog_name_from_automate(message = 'get_dialog_name', input_fields = [:request_type], extra_attrs = {})
    return nil if self.class.automate_dialog_request.nil?

    _log.info("Querying Automate Profile for dialog name")
    attrs = {'request' => self.class.automate_dialog_request, 'message' => message}
    extra_attrs.each { |k, v| attrs[k] = v }

    @values.each_key do |k|
      key = "dialog_input_#{k.to_s.downcase}"
      if attrs.key?(key)
        _log.info("Skipping key=<#{key}> because already set to <#{attrs[key]}>")
      else
        value = (k == :vm_tags) ? get_tags : get_value(@values[k]).to_s
        _log.info("Setting attrs[#{key}]=<#{value}>")
        attrs[key] = value
      end
    end

    input_fields.each { |k| attrs["dialog_input_#{k.to_s.downcase}"] = send(k).to_s }

    ws = MiqAeEngine.resolve_automation_object("REQUEST", @requester, attrs, :vmdb_object => @requester)

    if ws && ws.root
      dialog_option_prefix = 'dialog_option_'
      dialog_option_prefix_length = dialog_option_prefix.length
      ws.root.attributes.each do |key, value|
        next unless key.downcase.starts_with?(dialog_option_prefix)
        next unless key.length > dialog_option_prefix_length
        key = key[dialog_option_prefix_length..-1].downcase
        _log.info("Setting @values[#{key}]=<#{value}>")
        @values[key.to_sym] = value
      end

      name = ws.root("dialog_name")
      return name.presence
    end

    nil
  end

  def self.request_type(type)
    type.presence.try(:to_sym) || request_class.request_types.first
  end

  def request_type
    self.class.request_type(get_value(@values[:request_type]))
  end

  def request_class
    req_class = self.class.request_class
    return req_class unless get_value(@values[:service_template_request]) == true
    (req_class.name + "Template").constantize
  end

  def self.request_class
    @workflow_class ||= name.underscore.gsub(/_workflow$/, "_request").camelize.constantize
  end

  def set_default_values
    set_default_user_info rescue nil
  end

  def set_default_user_info
    return if get_dialog(:requester).blank?

    if get_value(@values[:owner_email]).blank? && @requester.email.present?
      @values[:owner_email] = @requester.email
      retrieve_ldap if MiqLdap.using_ldap?
    end

    show_flag = MiqLdap.using_ldap? ? :show : :hide
    show_fields(show_flag, [:owner_load_ldap])
  end

  def set_request_values(values)
    values[:requester_group] ||= @requester.current_group.description
    email = values[:owner_email]
    if email.present? && values[:owner_group].blank?
      values[:owner_group] = User.find_by_lower_email(email, @requester).try(:miq_group_description)
    end
  end

  def password_helper(values = @values, encrypt = true)
    self.class.encrypted_options_fields.each do |pwd_key|
      next if values[pwd_key].blank?
      if encrypt
        values[pwd_key].replace(MiqPassword.try_encrypt(values[pwd_key]))
      else
        values[pwd_key].replace(MiqPassword.try_decrypt(values[pwd_key]))
      end
    end
  end

  def update_field_visibility
  end

  def refresh_field_values(values)
    st = Time.now

    @values = values

    get_source_and_targets(true)

    # @values gets modified during this call
    get_all_dialogs

    values.merge!(@values)

    # Update the display flag for fields based on current settings
    update_field_visibility

    _log.info("refresh completed in [#{Time.now - st}] seconds")
  rescue => err
    $log.log_backtrace(err)
    raise
  end

  # Run the relationship methods and perform set intersections on the returned values.
  # Optional starting set of results maybe passed in.
  def allowed_ci(ci, relats, sources, filtered_ids = nil)
    result = nil
    relats.each do |rsc_type|
      rails_logger("allowed_ci - #{rsc_type}_to_#{ci}", 0)
      rc = send("#{rsc_type}_to_#{ci}", sources)
      rails_logger("allowed_ci - #{rsc_type}_to_#{ci}", 1)
      unless rc.nil?
        rc = rc.to_a
        result = result.nil? ? rc : result & rc
      end
    end
    result = [] if result.nil?
    result.reject! { |k, _v| !filtered_ids.include?(k) } unless filtered_ids.nil?
    result.each_with_object({}) { |s, hash| hash[s[0]] = s[1] }
  end

  def process_filter(filter_prop, ci_klass, targets)
    rails_logger("process_filter - [#{ci_klass}]", 0)
    filter_id = get_value(@values[filter_prop]).to_i
    MiqSearch.filtered(filter_id, ci_klass, targets,
                       :user      => @requester,
                       :miq_group => @requester.current_group,
                      ).tap { rails_logger("process_filter - [#{ci_klass}]", 1) }
  end

  def find_all_ems_of_type(klass, src = nil)
    result = []
    each_ems_metadata(src, klass) { |ci| result << ci }
    result
  end

  def find_hosts_under_ci(item)
    find_classes_under_ci(item, Host)
  end

  def find_respools_under_ci(item)
    find_classes_under_ci(item, ResourcePool)
  end

  def find_classes_under_ci(item, klass)
    results = []
    return results if item.nil?
    @_find_classes_under_ci_prefix ||= _log.prefix
    node = load_ems_node(item, @_find_classes_under_ci_prefix)
    each_ems_metadata(node.attributes[:object], klass) { |ci| results << ci } unless node.nil?
    results
  end

  def load_ems_node(item, log_header)
    @ems_xml_nodes ||= {}
    klass_name = item.kind_of?(MiqHashStruct) ? item.evm_object_class : item.class.base_class.name
    node = @ems_xml_nodes["#{klass_name}_#{item.id}"]
    $log.error("#{log_header} Resource <#{klass_name}_#{item.id} - #{item.name}> not found in cached resource tree.") if node.nil?
    node
  end

  def ems_has_clusters?
    found = each_ems_metadata(nil, EmsCluster) { |ci| break(ci) }
    return found.evm_object_class == :EmsCluster if found.kind_of?(MiqHashStruct)
    false
  end

  def get_ems_folders(folder, dh = {}, full_path = "")
    if folder.evm_object_class == :EmsFolder
      if folder.hidden
        return dh if folder.name != 'vm'
      else
        full_path += full_path.blank? ? folder.name.to_s : " / #{folder.name}"
        dh[folder.id] = full_path unless folder.type == "Datacenter"
      end
    end

    # Process child folders
    @_get_ems_folders_prefix ||= _log.prefix
    node = load_ems_node(folder, @_get_ems_folders_prefix)
    node.children.each { |child| get_ems_folders(child.attributes[:object], dh, full_path) } unless node.nil?

    dh
  end

  def get_ems_respool(node, dh = {}, full_path = "")
    return if node.nil?
    if node.kind_of?(XmlHash::Element)
      folder = node.attributes[:object]
      if node.name == :ResourcePool
        full_path += full_path.blank? ? folder.name.to_s : " / #{folder.name}"
        dh[folder.id] = full_path
      end
    end

    # Process child folders
    node.children.each { |child| get_ems_respool(child, dh, full_path) }

    dh
  end

  def find_datacenter_for_ci(item, ems_src = nil)
    find_class_above_ci(item, EmsFolder, ems_src, true)
  end

  def find_hosts_for_respool(item, ems_src = nil)
    hosts = find_class_above_ci(item, Host, ems_src)
    return [hosts] unless hosts.blank?

    cluster = find_cluster_above_ci(item)
    find_hosts_under_ci(cluster)
  end

  def find_cluster_above_ci(item, ems_src = nil)
    find_class_above_ci(item, EmsCluster, ems_src)
  end

  def find_class_above_ci(item, klass, _ems_src = nil, datacenter = false)
    result = nil
    @_find_class_above_ci_prefix ||= _log.prefix
    node = load_ems_node(item, @_find_class_above_ci_prefix)
    klass_name = klass.name.to_sym
    # Walk the xml document parents to find the requested class
    while node.kind_of?(XmlHash::Element)
      ci = node.attributes[:object]
      if node.name == klass_name && (datacenter == false || datacenter == true && ci.type == "Datacenter")
        result = ci
        break
      end
      node = node.parent
    end

    result
  end

  def each_ems_metadata(ems_ci = nil, klass = nil, &_blk)
    if ems_ci.nil?
      src = get_source_and_targets
      ems_xml = get_ems_metadata_tree(src)
      ems_node = ems_xml.try(:root)
    else
      @_each_ems_metadata_prefix ||= _log.prefix
      ems_node = load_ems_node(ems_ci, @_each_ems_metadata_prefix)
    end
    klass_name = klass.name.to_sym unless klass.nil?
    unless ems_node.nil?
      ems_node.each_recursive { |node| yield(node.attributes[:object]) if klass.nil? || klass_name == node.name }
    end
  end

  def get_ems_metadata_tree(src)
    @ems_metadata_tree ||= begin
      return if src[:ems].nil?
      st = Time.zone.now
      result = load_ar_obj(src[:ems]).fulltree_arranged(:except_type => "VmOrTemplate")
      ems_metadata_tree_add_hosts_under_clusters!(result)
      @ems_xml_nodes = {}
      xml = MiqXml.newDoc(:xmlhash)
      convert_to_xml(xml, result)
      _log.info("EMS metadata collection completed in [#{Time.zone.now - st}] seconds")
      xml
    end
  end

  def ems_metadata_tree_add_hosts_under_clusters!(result)
    result.each do |obj, children|
      ems_metadata_tree_add_hosts_under_clusters!(children)
      obj.hosts.each { |h| children[h] = {} } if obj.kind_of?(EmsCluster)
    end
  end

  def convert_to_xml(xml, result)
    result.each do |obj, children|
      @ems_xml_nodes["#{obj.class.base_class}_#{obj.id}"] = node = xml.add_element(obj.class.base_class.name, :object => ci_to_hash_struct(obj))
      convert_to_xml(node, children)
    end
  end

  def add_target(dialog_key, key, klass, result)
    key_id = "#{key}_id".to_sym
    result[key_id] = get_value(@values[dialog_key])
    result[key_id] = nil if result[key_id] == 0
    result[key] = ci_to_hash_struct(klass.find_by(:id => result[key_id])) unless result[key_id].nil?
  end

  def ci_to_hash_struct(ci)
    return if ci.nil?
    return ci.collect { |c| ci_to_hash_struct(c) } if ci.respond_to?(:collect)
    method_name = "#{ci.class.base_class.name.underscore}_to_hash_struct".to_sym
    return send(method_name, ci) if respond_to?(method_name, true)
    default_ci_to_hash_struct(ci)
  end

  def host_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :vmm_product, :vmm_version, :state, :v_total_vms, :maintenance])
  end

  def vm_or_template_to_hash_struct(ci)
    v = build_ci_hash_struct(ci, [:name, :platform])
    v.snapshots = ci.snapshots.collect { |si| ci_to_hash_struct(si) }
    v
  end

  def ems_folder_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :type, :hidden])
  end

  def storage_to_hash_struct(ci)
    storage_clusters = ci.storage_clusters.blank? ? nil : ci.storage_clusters.collect(&:name).join(', ')
    build_ci_hash_struct(ci, [:name, :free_space, :total_space, :storage_domain_type]).tap do |hs|
      hs.storage_clusters = storage_clusters
    end
  end

  def snapshot_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :current?])
  end

  def customization_spec_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :typ, :description, :last_update_time, :is_sysprep_spec?])
  end

  def load_ar_obj(ci)
    return load_ar_objs(ci) if ci.kind_of?(Array)
    return ci unless ci.kind_of?(MiqHashStruct)
    ci.evm_object_class.to_s.camelize.constantize.find_by(:id => ci.id)
  end

  def load_ar_objs(ci)
    ci.collect { |i| load_ar_obj(i) }
  end

  # Return empty hash if we are selecting placement automatically so we do not
  # spend time determining all the available resources
  def resources_for_ui
    get_source_and_targets
  end

  def allowed_hosts_obj(options = {})
    return [] if (src = resources_for_ui).blank? || src[:ems].nil?
    datacenter = src[:datacenter] || options[:datacenter]
    rails_logger('allowed_hosts_obj', 0)
    st = Time.now
    hosts_ids = find_all_ems_of_type(Host).collect(&:id)
    hosts_ids &= load_ar_obj(src[:storage]).hosts.collect(&:id) unless src[:storage].nil?
    if datacenter
      @_allowed_hosts_obj_prefix ||= _log.prefix
      dc_node = load_ems_node(datacenter, @_allowed_hosts_obj_prefix)
      hosts_ids &= find_hosts_under_ci(dc_node.attributes[:object]).collect(&:id)
    end
    return [] if hosts_ids.blank?

    # Remove any hosts that are no longer in the list
    all_hosts = load_ar_obj(src[:ems]).hosts.find_all { |h| hosts_ids.include?(h.id) }
    allowed_hosts_obj_cache = process_filter(:host_filter, Host, all_hosts)
    _log.info("allowed_hosts_obj returned [#{allowed_hosts_obj_cache.length}] objects in [#{Time.now - st}] seconds")
    rails_logger('allowed_hosts_obj', 1)
    allowed_hosts_obj_cache
  end

  def allowed_storages(_options = {})
    return [] if (src = resources_for_ui).blank? || src[:ems].nil?
    hosts = src[:host].nil? ? allowed_hosts_obj({}) : [load_ar_obj(src[:host])]
    return [] if hosts.blank?

    rails_logger('allowed_storages', 0)
    st = Time.now
    MiqPreloader.preload(hosts, :storages => {}, :host_storages => :storage)

    storages = hosts.each_with_object({}) do |host, hash|
      host.writable_storages.each { |s| hash[s.id] = s }
    end.values
    selected_storage_profile_id = get_value(@values[:placement_storage_profile])
    if selected_storage_profile_id
      storages.reject! { |s| !s.storage_profiles.pluck(:id).include?(selected_storage_profile_id) }
    end
    allowed_storages_cache = process_filter(:ds_filter, Storage, storages).collect do |s|
      ci_to_hash_struct(s)
    end

    _log.info("allowed_storages returned [#{allowed_storages_cache.length}] objects in [#{Time.now - st}] seconds")
    rails_logger('allowed_storages', 1)
    allowed_storages_cache
  end

  def allowed_hosts(_options = {})
    hosts = allowed_hosts_obj
    hosts_ids = hosts.collect(&:id)
    result_hosts_hash = allowed_ci(:host, [:cluster, :respool, :folder], hosts_ids)

    host_ids = result_hosts_hash.to_a.transpose.first
    return [] if host_ids.nil?

    find_all_ems_of_type(Host).collect { |h| h if host_ids.include?(h.id) }.compact
  end

  def allowed_datacenters(_options = {})
    allowed_ci(:datacenter, [:cluster, :respool, :host, :folder])
  end

  def allowed_clusters(_options = {})
    all_clusters     = EmsCluster.where(:ems_id => get_source_and_targets[:ems].try(:id))
    filtered_targets = process_filter(:cluster_filter, EmsCluster, all_clusters)
    allowed_ci(:cluster, [:respool, :host, :folder], filtered_targets.collect(&:id))
  end

  def allowed_respools(_options = {})
    all_resource_pools = ResourcePool.where(:ems_id => get_source_and_targets[:ems].try(:id))
    filtered_targets   = process_filter(:rp_filter, ResourcePool, all_resource_pools)
    allowed_ci(:respool, [:cluster, :host, :folder], filtered_targets.collect(&:id))
  end
  alias_method :allowed_resource_pools, :allowed_respools

  def allowed_folders(_options = {})
    allowed_ci(:folder, [:cluster, :host, :respool])
  end

  def cluster_to_datacenter(src)
    return nil unless ems_has_clusters?
    ci_to_datacenter(src, :cluster, EmsCluster)
  end

  def respool_to_datacenter(src)
    ci_to_datacenter(src, :respool, ResourcePool)
  end

  def host_to_datacenter(src)
    ci_to_datacenter(src, :host, Host)
  end

  def folder_to_datacenter(src)
    return nil if src[:folder].nil?
    ci_to_datacenter(src, :folder, EmsFolder)
  end

  def ci_to_datacenter(src, ci, ci_type)
    sources = src[ci].nil? ? find_all_ems_of_type(ci_type) : [src[ci]]
    sources.collect { |c| find_datacenter_for_ci(c) }.compact.uniq.each_with_object({}) { |c, r| r[c.id] = c.name }
  end

  def respool_to_cluster(src)
    return nil unless ems_has_clusters?
    sources = src[:respool].nil? ? find_all_ems_of_type(ResourcePool) : [src[:respool]]
    build_id_to_name_hash(sources.collect { |rp| find_cluster_above_ci(rp) }.compact)
  end

  def host_to_cluster(src)
    return nil unless ems_has_clusters?
    sources = src[:host].nil? ? allowed_hosts_obj : [src[:host]]
    build_id_to_name_hash(sources.collect { |h| find_cluster_above_ci(h) }.compact)
  end

  def folder_to_cluster(src)
    return nil unless ems_has_clusters?
    source = find_all_ems_of_type(EmsCluster)
    build_id_to_name_hash(filter_to_objects_in_same_datacenter(source, src))
  end

  def cluster_to_respool(src)
    return nil unless ems_has_clusters?
    targets = src[:cluster].nil? ? find_all_ems_of_type(ResourcePool) : find_respools_under_ci(src[:cluster])
    res_pool_with_path = get_ems_respool(get_ems_metadata_tree(src))
    targets.each_with_object({}) { |rp, r| r[rp.id] = res_pool_with_path[rp.id] }
  end

  def folder_to_respool(src)
    return nil if src[:folder].nil?
    datacenter = find_datacenter_for_ci(src[:folder])
    targets = find_respools_under_ci(datacenter)
    res_pool_with_path = get_ems_respool(get_ems_metadata_tree(src))
    targets.each_with_object({}) { |rp, r| r[rp.id] = res_pool_with_path[rp.id] }
  end

  def host_to_respool(src)
    hosts = src[:host].nil? ? allowed_hosts_obj : [src[:host]]
    targets = hosts.collect do |h|
      cluster = find_cluster_above_ci(h)
      source = cluster.nil? ? h : cluster
      find_respools_under_ci(source)
    end.flatten
    res_pool_with_path = get_ems_respool(get_ems_metadata_tree(src))
    targets.each_with_object({}) { |rp, r| r[rp.id] = res_pool_with_path[rp.id] }
  end

  def cluster_to_host(src)
    return nil unless ems_has_clusters?
    hosts = src[:cluster].nil? ? find_all_ems_of_type(Host) : find_hosts_under_ci(src[:cluster])
    build_id_to_name_hash(hosts)
  end

  def respool_to_host(src)
    hosts = src[:respool].nil? ? find_all_ems_of_type(Host) : find_hosts_for_respool(src[:respool])
    build_id_to_name_hash(hosts)
  end

  def folder_to_host(src)
    source = find_all_ems_of_type(Host)
    build_id_to_name_hash(filter_to_objects_in_same_datacenter(source, src))
  end

  def host_to_folder(src)
    sources = src[:host].nil? ? allowed_hosts_obj : [src[:host]]
    datacenters = sources.collect do |h|
      rails_logger("host_to_folder for host #{h.name}", 0)
      result = find_datacenter_for_ci(h)
      rails_logger("host_to_folder for host #{h.name}", 1)
      result
    end.compact
    datacenters.each_with_object({}) do |dc, folders|
      rails_logger("host_to_folder for dc #{dc.name}", 0)
      folders.merge!(get_ems_folders(dc))
      rails_logger("host_to_folder for dc #{dc.name}", 1)
    end
  end

  def cluster_to_folder(src)
    return nil unless ems_has_clusters?
    return nil if src[:cluster].nil?
    sources = [src[:cluster]]
    datacenters = sources.collect { |h| find_datacenter_for_ci(h) }.compact
    datacenters.each_with_object({}) { |dc, folders| folders.merge!(get_ems_folders(dc)) }
  end

  def respool_to_folder(src)
    return nil if src[:respool].nil?
    sources = [src[:respool]]
    datacenters = sources.collect { |h| find_datacenter_for_ci(h) }.compact
    datacenters.each_with_object({}) { |dc, folders| folders.merge!(get_ems_folders(dc)) }
  end

  def set_ws_field_value(values, key, data, dialog_name, dlg_fields)
    value = data.delete(key)

    dlg_field = dlg_fields[key]
    data_type = dlg_field[:data_type]
    set_value = cast_value(value, data_type)

    result = nil
    if dlg_field.key?(:values)
      get_source_and_targets(true)
      get_field(key, dialog_name)
      field_values = dlg_field[:values]
      _log.info("processing key <#{dialog_name}:#{key}(#{data_type})> with values <#{field_values.inspect}>")
      if field_values.present?
        result = if field_values.first.kind_of?(MiqHashStruct)
                   found = field_values.detect { |v| v.id == set_value }
                   [found.id, found.name] if found
                 elsif data_type == :array_integer
                   field_values.keys & set_value
                 else
                   [set_value, field_values[set_value]] if field_values.key?(set_value)
                 end

        set_value = apply_result(result, data_type)
      end
    end

    _log.warn("Unable to find value for key <#{dialog_name}:#{key}(#{data_type})> with input value <#{set_value.inspect}>.  No matching item found.") if result.nil?
    _log.info("setting key <#{dialog_name}:#{key}(#{data_type})> to value <#{set_value.inspect}>")
    values[key] = set_value
  end

  def cast_value(value, data_type)
    case data_type
    when :integer         then value.to_i_with_method
    when :float           then value.to_f
    when :boolean         then value.to_s.downcase.in?(%w(true t))
    when :time            then Time.zone.parse(value)
    when :button          then value # Ignore
    when :array_integer   then value.to_miq_a.map!(&:to_i)
    else value # Ignore
    end
  end

  def set_ws_field_value_by_display_name(values, key, data, dialog_name, dlg_fields, obj_key = :name)
    value = data.delete(key)

    dlg_field = dlg_fields[key]
    data_type = dlg_field[:data_type]
    find_value = value.to_s.downcase

    if dlg_field.key?(:values)
      field_values = dlg_field[:values]
      _log.info("processing key <#{dialog_name}:#{key}(#{data_type})> with values <#{field_values.inspect}>")
      if field_values.present?
        result = if field_values.first.kind_of?(MiqHashStruct)
                   found = field_values.detect { |v| v.send(obj_key).to_s.downcase == find_value }
                   [found.id, found.send(obj_key)] if found
                 else
                   field_values.detect { |_k, v| v.to_s.downcase == find_value }
                 end

        if result.nil?
          _log.warn("Unable to set key <#{dialog_name}:#{key}(#{data_type})> to value <#{find_value.inspect}>.  No matching item found.")
        else
          set_value = [result.first, result.last]
          _log.info("setting key <#{dialog_name}:#{key}(#{data_type})> to value <#{set_value.inspect}>")
          values[key] = set_value
        end
      end
    end
  end

  def set_ws_field_value_by_id_or_name(values, dlg_field, data, dialog_name, dlg_fields, data_key = nil, id_klass = nil)
    data_key = dlg_field if data_key.blank?
    if data.key?(data_key)
      data[data_key] = "#{id_klass}::#{data[data_key]}" unless id_klass.blank?
      data[dlg_field] = data.delete(data_key)
      set_ws_field_value(values, dlg_field, data, dialog_name, dlg_fields)
    else
      data_key_without_id = data_key.to_s.chomp('_id').to_sym
      if data.key?(data_key_without_id)
        data[data_key] = data.delete(data_key_without_id)
        data[dlg_field] = data.delete(data_key)
        set_ws_field_value_by_display_name(values, dlg_field, data, dialog_name, dlg_fields, :name)
      end
    end
  end

  def get_ws_dialog_fields(dialog_name)
    dlg_fields = @dialogs.fetch_path(:dialogs, dialog_name, :fields)
    _log.info("<#{dialog_name}> dialog not found in dialogs.  Field updates will be skipped.") if dlg_fields.nil?
    dlg_fields
  end

  def allowed_customization_templates(_options = {})
    result = []
    customization_template_id = get_value(@values[:customization_template_id])
    @values[:customization_template_script] = nil if customization_template_id.nil?
    prov_typ = self.class == MiqHostProvisionWorkflow ? "host" : "vm"
    image = supports_iso? ? get_iso_image : get_pxe_image
    unless image.nil?
      result = image.customization_templates.collect do |c|
        # filter customizationtemplates
        if c.pxe_image_type.provision_type.blank? || c.pxe_image_type.provision_type == prov_typ
          @values[:customization_template_script] = c.script if c.id == customization_template_id
          build_ci_hash_struct(c, [:name, :description, :updated_at])
        end
      end.compact
    end

    @values[:customization_template_script] = nil if result.blank?
    result
  end

  def get_iso_image
    get_image_by_type(:iso_image_id)
  end

  def get_pxe_image
    get_image_by_type(:pxe_image_id)
  end

  def get_image_by_type(image_type)
    klass, id = get_value(@values[image_type]).to_s.split('::')
    return nil if id.blank?
    klass.constantize.find_by(:id => id)
  end

  def get_pxe_server
    PxeServer.find_by(:id => get_value(@values[:pxe_server_id]))
  end

  def allowed_pxe_servers(_options = {})
    PxeServer.all.each_with_object({}) { |p, h| h[p.id] = p.name }
  end

  def allowed_pxe_images(_options = {})
    pxe_server = get_pxe_server
    return [] if pxe_server.nil?
    prov_typ = self.class == MiqHostProvisionWorkflow ? "host" : "vm"

    pxe_server.pxe_images.collect do |p|
      next if p.pxe_image_type.nil? || p.default_for_windows
      # filter pxe images by provision_type to show vm/any or host/any
      build_ci_hash_struct(p, [:name, :description]) if p.pxe_image_type.provision_type.blank? || p.pxe_image_type.provision_type == prov_typ
    end.compact
  end

  def allowed_windows_images(_options = {})
    pxe_server = get_pxe_server
    return [] if pxe_server.nil?

    pxe_server.windows_images.collect do |p|
      build_ci_hash_struct(p, [:name, :description])
    end.compact
  end

  def allowed_images(options = {})
    result = allowed_pxe_images(options) + allowed_windows_images(options)
    # Change the ID to contain the class name since this is a mix class type
    result.each { |ci| ci.id = "#{ci.evm_object_class}::#{ci.id}" }
    result
  end

  def get_iso_images
    template = VmOrTemplate.find_by(:id => get_value(@values[:src_vm_id]))
    template.try(:ext_management_system).try(:iso_datastore).try(:iso_images) || []
  end

  def allowed_iso_images(_options = {})
    result = get_iso_images.collect do |p|
      build_ci_hash_struct(p, [:name])
    end.compact
    # Change the ID to contain the class name since this is a mix class type
    result.each { |ci| ci.id = "#{ci.evm_object_class}::#{ci.id}" }
    result
  end

  def ws_requester_fields(values, fields)
    dialog_name = :requester
    dlg_fields = @dialogs.fetch_path(:dialogs, :requester, :fields)
    if dlg_fields.nil?
      _log.info("<#{dialog_name}> dialog not found in dialogs.  Field updates be skipped.")
      return
    end

    data = parse_ws_string(fields)
    _log.info("data:<#{data.inspect}>")
    values[:auto_approve] = data.delete(:auto_approve) == 'true'
    data.delete(:user_name)

    # get owner values from LDAP if configured
    if data[:owner_email].present? && MiqLdap.using_ldap?
      email = data[:owner_email]
      unless email.include?('@')
        email = "#{email}@#{::Settings.authentication.user_suffix}"
      end
      values[:owner_email] = email
      retrieve_ldap rescue nil
    end

    dlg_keys = dlg_fields.keys
    data.keys.each do |key|
      if dlg_keys.include?(key)
        _log.info("processing key <#{dialog_name}:#{key}> with value <#{data[key].inspect}>")
        values[key] = data[key]
      else
        _log.warn("Skipping key <#{dialog_name}:#{key}>.  Key name not found in dialog")
      end
    end
  end

  def ws_schedule_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :schedule)).nil?

    unless data[:schedule_time].blank?
      values[:schedule_type] = 'schedule'
      [:schedule_time, :retirement_time].each do |key|
        data_type = :time
        time_value = data.delete(key)
        set_value = time_value.blank? ? nil : Time.parse(time_value)
        _log.info("setting key <#{dialog_name}:#{key}(#{data_type})> to value <#{set_value.inspect}>")
        values[key] = set_value
      end
    end

    dlg_keys = dlg_fields.keys
    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key) }
  end

  def raise_validate_errors
    errors = []
    fields { |_fn, f, _dn, _d| errors << f[:error] unless f[:error].nil? }
    err_text = "Provision failed for the following reasons:\n#{errors.join("\n")}"
    _log.error("<#{err_text}>")
    raise _("Provision failed for the following reasons:\n%{errors}") % {:errors => errors.join("\n")}
  end

  private

  def apply_result(result, data_type)
    return result if data_type == :array_integer
    [result.first, result.last] unless result.nil?
  end

  def build_id_to_name_hash(array)
    array.each_with_object({}) { |i, h| h[i.id] = i.name }
  end

  def default_ci_to_hash_struct(ci)
    attributes = []
    attributes << :name if ci.respond_to?(:name)
    build_ci_hash_struct(ci, attributes)
  end

  def filter_to_objects_in_same_datacenter(array, source)
    # If a folder is selected, reduce the host/cluster list to only hosts/clusters in the same datacenter as the folder
    source[:datacenter] ? array.reject { |i| find_datacenter_for_ci(i).id != source[:datacenter].id } : array
  end
end
