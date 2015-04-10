require 'enumerator'
require 'miq-hash_struct'

class MiqRequestWorkflow
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

  def self.all_encrypted_options_fields
    descendants.flat_map(&:encrypted_options_fields).uniq
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
    @requester    = MiqLdap.using_ldap? ? User.find_or_create_by_ldap_upn(requester) : User.find_by_userid(requester)
    @values.merge!(options) unless options.blank?
  end

  def create_request(values, requester_id, target_class, event_name, event_message, auto_approve = false)
    log_header = "MIQ(#{self.class.name}#create_request)"
    return false unless validate(values)

    # Ensure that tags selected in the pre-dialog get applied to the request
    values[:vm_tags] = (values[:vm_tags].to_miq_a + @values[:pre_dialog_vm_tags]).uniq unless @values.nil? || @values[:pre_dialog_vm_tags].blank?

    password_helper(values, true)

    yield if block_given?

    request = request_class.create(:options => values, :userid => requester_id, :request_type => request_type.to_s)
    begin
      request.save!  # Force validation errors to raise now
    rescue => err
      $log.error "#{log_header} [#{err}]"
      $log.error err.backtrace.join("\n")
      return request
    end

    request.set_description
    request.create_request

    AuditEvent.success(
      :event        => event_name,
      :target_class => target_class,
      :userid       => requester_id,
      :message      => event_message
    )

    request.call_automate_event_queue("request_created")
    request.approve(requester_id, "Auto-Approved") if auto_approve == true
    request
  end

  def update_request(request, values, requester_id, target_class, event_name, event_message)
    request = request.kind_of?(MiqRequest) ? request : MiqRequest.find(request)

    return false unless validate(values)

    # Ensure that tags selected in the pre-dialog get applied to the request
    values[:vm_tags] = (values[:vm_tags].to_miq_a + @values[:pre_dialog_vm_tags]).uniq  unless @values[:pre_dialog_vm_tags].blank?

    password_helper(values, true)

    yield if block_given?

    request.update_attribute(:options, request.options.merge(values))
    request.set_description(true)

    AuditEvent.success(
      :event        => event_name,
      :target_class => target_class,
      :userid       => requester_id,
      :message      => event_message
    )

    request.call_automate_event_queue("request_updated")

    request
  end

  def init_from_dialog(values, _userid)
    options = values
    values_new = options

    get_all_dialogs.keys.each do |d|                         # Go thru all dialogs
      get_all_fields(d).keys.each do |f|                     # Go thru all field
        if !options[f].nil?
          values_new[f] = options[f]                              # Set the existing option value
        else
          field = get_field(f, d)
          if field[:display] != :ignore
            if !field[:default].nil?
              val = field[:default]                               # Set to default value
            elsif field[:values] && field[:values].length == 1    # if default is not set to anything and there is only one value in hash, use set element to be displayed default
              field[:values].each do |v|
                val = v[0]
              end
            end
            if field[:values]                                     # If this field has values
              if field[:values].kind_of?(Hash)
                values_new[f] = [val, field[:values][val]]        # Save [value, description], skip for timezones array
              else
                field[:values].each do |tz|
                  if tz[1].to_i_with_method == val.to_i_with_method
                    values_new[f] = [val, tz[0]]                  # Save [value, description] for timezones array
                  end
                end
              end
            else
              values_new[f] = val                                 # Set to default value
            end
          end
        end
      end # get_all_fields
    end # get_all_dialogs
  end

  def validate(values)
    # => Input - A hash keyed by field name with entered values
    # => Output - true || false
    #
    # Update @dialogs adding error keys to fields that don't validate
    valid = true

    get_all_dialogs.each do |d, dlg|
      # Check if the entire dialog is ignored or disabled and check while processing the fields
      dialog_disabled = !dialog_active?(d, dlg, values)

      get_all_fields(d).each do |f, fld|
        fld[:error] = nil

        # Check the disabled flag here so we reset the "error" value on each field
        next if dialog_disabled || fld[:display] == :hide

        value = get_value(values[f])

        if fld[:required] == true
          # If :required_method is defined let it determine if the field is value
          unless fld[:required_method].nil?
            fld[:error] = send(fld[:required_method], f, values, dlg, fld, value)
            unless fld[:error].nil?
              valid = false
              next
            end
          else
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
          end
        end

        if fld[:validation_method] && respond_to?(fld[:validation_method])
          valid = !(fld[:error] = send(fld[:validation_method], f, values, dlg, fld, value))
          next unless valid
        end

        next if value.blank?

        msg = "'#{fld[:description]}' in dialog #{dlg[:description]} must be of type #{fld[:data_type]}"
        case fld[:data_type]
        when :integer
          unless is_integer?(value)
            fld[:error] = msg; valid = false
          end
        when :float
          unless is_numeric?(value)
            fld[:error] = msg; valid = false
          end
        when :boolean
          # TODO: do we need validation for boolean
        when :button
          # Ignore
        else
          data_type = Object.const_get(fld[:data_type].to_s.camelize)
          unless value.kind_of?(data_type)
            fld[:error] = msg; valid = false
          end
        end
      end
    end

    valid
  end

  def get_dialog_order
    @dialogs[:dialog_order]
  end

  def get_buttons
    @dialogs[:buttons] || [:submit, :cancel]
  end

  def get_all_dialogs
    @dialogs[:dialogs].each_key { |d| get_dialog(d) }
    @dialogs[:dialogs]
  end

  def get_dialog(dialog_name)
    dialog = @dialogs.fetch_path(:dialogs, dialog_name.to_sym)
    return {} unless dialog

    get_all_fields(dialog_name)
    dialog
  end

  def get_all_fields(dialog_name)
    dialog = @dialogs.fetch_path(:dialogs, dialog_name.to_sym)
    return {} unless dialog

    dialog[:fields].each_key { |f| get_field(f, dialog_name) }
    dialog[:fields]
  end

  def get_field(field_name, dialog_name = nil)
    field_name = field_name.to_sym
    dialog_name = find_dialog_from_field_name(field_name) if dialog_name.nil?
    field = @dialogs.fetch_path(:dialogs, dialog_name.to_sym, :fields, field_name)
    return {} unless field

    if field.key?(:values_from)
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
      next if value.blank?
      key = key.strip.downcase.to_sym unless options[:modify_key_name] == false
      hash[key] = value
    end
  end

  def set_ws_tags(values, tag_string, parser = :parse_ws_string)
    # Tags are passed as category|value.  Example: cc|001|environment|test
    ta = []
    ws_tags = send(parser, tag_string)

    tags = {}
    send(:allowed_tags).each do |v|
      tc = tags[v[:name]] = {}
      v[:children].each { |k, v| tc[v[:name]] = k }
    end

    ws_tags.each { |cat, tag| ta << tags.fetch_path(cat.to_s.downcase, tag.downcase) }
    values[:vm_tags] = ta.compact
  end

  def set_ws_values(values, key_name, additional_values, parser = :parse_ws_string, parser_options = {})
    # Tags are passed as category=value.  Example: cc=001|environment=test
    ws_values = values[key_name] = {}
    parsed_values = send(parser, additional_values, parser_options)
    parsed_values.each { |k, v| ws_values[k.to_sym] = v }
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
    return data.first if data.kind_of?(Array)
    data
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
    header = "MIQ(#{self.class.name}.set_value_from_list)"
    @values[fn] = [nil, nil]
    values = f[:values] if values.nil?
    unless value.nil?
      @values[fn] = values.to_a.detect do |v|
        if partial_key
          $log.warn "#{header} comparing [#{v[0]}] to [#{value}]"
          v[0].to_s.downcase.include?(value.to_s.downcase)
        else
          v.include?(value)
        end
      end
      if @values[fn].nil?
        $log.info "#{header} set_value_from_list did not matched an item" if partial_key
        @values[fn] = [nil, nil]
      else
        $log.info "#{header} set_value_from_list matched item value:[#{value}] to item:[#{@values[fn][0]}]" if partial_key
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

  def validate_tags(field, values, _dlg, fld, _value)
    selected_tags_categories = values[field].to_miq_a.collect { |tag_id| Classification.find_by_id(tag_id).parent.name.to_sym }
    required_tags = fld[:required_tags].to_miq_a.collect(&:to_sym)
    missing_tags = required_tags - selected_tags_categories
    missing_categories_names = missing_tags.collect { |category| Classification.find_by_name(category.to_s).description rescue nil }.compact
    return nil if missing_categories_names.blank?
    "Required tag(s): #{missing_categories_names.join(', ')}"
  end

  def validate_length(_field, _values, dlg, fld, value)
    return "#{required_description(dlg, fld)} is required" if value.blank?
    return "#{required_description(dlg, fld)} must be at least #{fld[:min_length]} characters"  if fld[:min_length] && value.to_s.length < fld[:min_length]
    return "#{required_description(dlg, fld)} must not be greater than #{fld[:max_length]} characters" if fld[:max_length] && value.to_s.length > fld[:max_length]
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

  def set_default_user_info
    if get_value(@values[:owner_email]).blank?
      unless @requester.email.blank?
        @values[:owner_email] = @requester.email
        retrieve_ldap if MiqLdap.using_ldap?
      end
    end

    show_flag = MiqLdap.using_ldap? ? :show : :hide
    show_fields(show_flag, [:owner_load_ldap])
  end

  def retrieve_ldap(_options = {})
    email = get_value(@values[:owner_email])
    unless email.blank?
      l = MiqLdap.new
      if l.bind_with_default == true
        raise "No information returned for #{email}" if (d = l.get_user_info(email)).nil?
        [:first_name, :last_name, :address, :city, :state, :zip, :country, :title, :company,
         :department, :office, :phone, :phone_mobile, :manager, :manager_mail, :manager_phone].each do |prop|
          @values["owner_#{prop}".to_sym] = d[prop].nil? ? nil : d[prop].dup
        end
        @values[:sysprep_organization] = d[:company].nil? ? nil : d[:company].dup
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
    results = {}
    options[:values].each { |k, v| results[k.to_i_with_method] = v }
    field, include_equals = options[:field], options[:include_equals]
    max_value = field.nil? ? options[:value].to_i_with_method : get_value(@values[field]).to_i_with_method
    return results if max_value <= 0
    results.reject { |k, _v| include_equals == true ? max_value < k : max_value <= k }
  end

  def tags
    vm_tags = @values[:vm_tags]
    vm_tags.each do |tag_id|
      tag = Classification.find(tag_id)
      yield(tag.name, tag.parent.name)  unless tag.nil?    # yield the tag's name and category
    end if vm_tags.kind_of?(Array)
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

    # TODO: Call allowed_tags properly from controller - it is currently hard-coded with no options passed
    field_options = @dialogs.fetch_path(:dialogs, :purpose, :fields, :vm_tags, :options)
    options = field_options unless field_options.nil?

    rails_logger('allowed_tags', 0)
    st = Time.now
    @tags = {}
    class_tags = Classification.where(:show => true).includes(:tag).to_a
    class_tags.reject!(&:read_only?) # Can't do in query because column is a string.

    exclude_list  = options[:exclude].blank?       ? [] : options[:exclude].collect(&:to_s)
    include_list  = options[:include].blank?       ? [] : options[:include].collect(&:to_s)
    single_select = options[:single_select].blank? ? [] : options[:single_select].collect(&:to_s)

    cats, ents = class_tags.partition { |t| t.parent_id == 0 }
    cats.each do |t|
      next unless t.tag2ns(t.tag.name) == "/managed"
      next if exclude_list.include?(t.name)
      next unless include_list.blank? || include_list.include?(t.name)
      # Force passed tags to be single select
      single_value = single_select.include?(t.name) ? true : t.single_value?
      @tags[t.id] = {:name => t.name, :description => t.description, :single_value => single_value, :children => {}, :id => t.id}
    end
    ents.each do |t|
      if @tags.key?(t.parent_id)
        full_tag_name = "#{@tags[t.parent_id][:name]}/#{t.name}"
        next if exclude_list.include?(full_tag_name)
        @tags[t.parent_id][:children][t.id] = {:name => t.name, :description => t.description}
      end
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
    $log.info "MIQ(#{self.class.name}.allowed_tags) allowed_tags returned [#{@tags.length}] objects in [#{Time.now - st}] seconds"
    @tags
  end

  def allowed_tags_and_pre_tags
    pre_tags = @values[:pre_dialog_vm_tags].to_miq_a
    return allowed_tags if pre_tags.blank?

    tag_cats = allowed_tags.dup
    tag_cat_names = tag_cats.collect { |cat| cat[:name] }

    Classification.find_all_by_id(pre_tags).each do |tag|
      parent = tag.parent
      next if tag_cat_names.include?(parent.name)

      new_cat = {:name => parent.name, :description => parent.description, :single_value => parent.single_value?, :children => {}, :id => parent.id}
      parent.children.each { |c| new_cat[:children][c.id] = {:name => c.name, :description => c.description} }
      tag_cats << new_cat
      tag_cat_names << new_cat[:name]
    end

    tag_cats
  end

  def build_ci_hash_struct(ci, props)
    nh = MiqHashStruct.new(:id => ci.id, :evm_object_class => ci.class.base_class.name.to_sym)
    props.each { |p| nh.send("#{p}=", ci.send(p)) }
    nh
  end

  def get_dialogs
    log_header = "MIQ(#{self.class.name}.get_dialogs)"

    @values[:miq_request_dialog_name] ||= @values[:provision_dialog_name] || dialog_name_from_automate || self.class.default_dialog_file
    dp = @values[:miq_request_dialog_name] = File.basename(@values[:miq_request_dialog_name], ".rb")
    $log.info "#{log_header} Loading dialogs <#{dp}> for user <#{@requester.userid}>"
    d = MiqDialog.where("lower(name) = ? and dialog_type = ?", dp.downcase, self.class.base_model.name).first
    raise MiqException::Error, "Dialog cannot be found.  Name:[#{@values[:miq_request_dialog_name]}]  Type:[#{self.class.base_model.name}]" if d.nil?
    prov_dialogs = d.content

    prov_dialogs
  end

  def get_pre_dialogs
    log_header = "MIQ(#{self.class.name}.get_pre_dialogs)"
    pre_dialogs = nil
    pre_dialog_name = dialog_name_from_automate('get_pre_dialog_name')
    unless pre_dialog_name.blank?
      pre_dialog_name = File.basename(pre_dialog_name, ".rb")
      d = MiqDialog.find_by_name_and_dialog_type(pre_dialog_name, self.class.base_model.name)
      unless d.nil?
        $log.info "#{log_header} Loading pre-dialogs <#{pre_dialog_name}> for user <#{@requester.userid}>"
        pre_dialogs = d.content
      end
    end

    pre_dialogs
  end

  def dialog_name_from_automate(message = 'get_dialog_name', input_fields = [:request_type], extra_attrs = {})
    log_header = "MIQ(#{self.class.name}.dialog_name_from_automate)"

    return nil if self.class.automate_dialog_request.nil?

    $log.info "#{log_header}: Querying Automate Profile for dialog name"
    attrs = {'request' => self.class.automate_dialog_request, 'message' => message}
    extra_attrs.each { |k, v| attrs[k] = v }

    @values.each_key do |k|
      key = "dialog_input_#{k.to_s.downcase}"
      if attrs.key?(key)
        $log.info "#{log_header}: Skipping key=<#{key}> because already set to <#{attrs[key]}>"
      else
        value = (k == :vm_tags) ? get_tags : get_value(@values[k]).to_s
        $log.info "#{log_header}: Setting attrs[#{key}]=<#{value}>"
        attrs[key] = value
      end
    end

    input_fields.each { |k| attrs["dialog_input_#{k.to_s.downcase}"] = send(k).to_s }

    uri  = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => @requester)
    ws   = MiqAeEngine.resolve_automation_object(uri)

    if ws && ws.root
      dialog_option_prefix = 'dialog_option_'
      dialog_option_prefix_length = dialog_option_prefix.length
      ws.root.attributes.each do |key, value|
        next unless key.downcase.starts_with?(dialog_option_prefix)
        next unless key.length > dialog_option_prefix_length
        key = key[dialog_option_prefix_length..-1].downcase
        $log.info "#{log_header}: Setting @values[#{key}]=<#{value}>"
        @values[key.to_sym] = value
      end

      name = ws.root("dialog_name")
      return name.presence
    end

    nil
  end

  def self.request_type(type)
    type.presence.try(:to_sym) || request_class::REQUEST_TYPES.first
  end

  def request_type
    self.class.request_type(get_value(@values[:request_type]))
  end

  def request_class
    req_class = self.class.request_class
    if get_value(@values[:service_template_request]) == true
      req_class = (req_class.name + "Template").constantize
    end
    req_class
  end

  def self.request_class
    @workflow_class ||= name.underscore.gsub(/_workflow$/, "_request").camelize.constantize
  end

  def set_default_values
    set_default_user_info rescue nil
  end

  def set_default_user_info
    return if get_dialog(:requester).blank?

    if get_value(@values[:owner_email]).blank?
      unless @requester.email.blank?
        @values[:owner_email] = @requester.email
        retrieve_ldap if MiqLdap.using_ldap?
      end
    end

    show_flag = MiqLdap.using_ldap? ? :show : :hide
    show_fields(show_flag, [:owner_load_ldap])
  end

  def password_helper(values, encrypt = true)
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

  def refresh_field_values(values, _requester_id)
    log_header = "MIQ(#{self.class.name}.refresh_field_values)"

    begin
      st = Time.now

      @values = values

      get_source_and_targets(true)

      # @values gets modified during this call
      get_all_dialogs

      values.merge!(@values)

      # Update the display flag for fields based on current settings
      update_field_visibility

      $log.info "MIQ(#{self.class.name}.refresh_field_values) refresh completed in [#{Time.now - st}] seconds"
    rescue => err
      $log.error "#{log_header} [#{err}]"
      $log.error err.backtrace.join("\n")
      raise err
    end
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
    result.inject({}) { |r, s| r[s[0]] = s[1]; r }
  end

  def process_filter(filter_prop, ci_klass, targets = [])
    return targets if targets.blank?
    process_filter_all(filter_prop, ci_klass, targets)
  end

  def process_filter_all(filter_prop, ci_klass, targets = [])
    rails_logger("process_filter - [#{ci_klass}]", 0)
    filter_id = get_value(@values[filter_prop]).to_i
    result =  unless filter_id.zero?
                MiqSearch.find(filter_id).search(targets, :results_format => :objects, :userid => @requester.userid).first
              else
                Rbac.search(:targets => targets, :class => ci_klass, :results_format => :objects, :userid => @requester.userid).first
              end
    rails_logger("process_filter - [#{ci_klass}]", 1)
    result
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
    log_header = "MIQ(#{self.class.name}.find_classes_under_ci)"
    results = []
    return results if item.nil?
    node = load_ems_node(item, log_header)
    each_ems_metadata(node.attributes[:object], klass) { |ci| results << ci } unless node.nil?
    results
  end

  def load_ems_node(item, log_header)
    klass_name = item.kind_of?(MiqHashStruct) ? item.evm_object_class : item.class.base_class.name
    node = @ems_xml_nodes["#{klass_name}_#{item.id}"]
    $log.error "#{log_header} Resource <#{klass_name}_#{item.id} - #{item.name}> not found in cached resource tree." if node.nil?
    node
  end

  def ems_has_clusters?
    found = each_ems_metadata(nil, EmsCluster) { |ci| break(ci) }
    return found.evm_object_class == :EmsCluster if found.kind_of?(MiqHashStruct)
    false
  end

  def get_ems_folders(folder, dh = {}, full_path = "")
    log_header = "MIQ(#{self.class.name}.get_ems_folders)"
    if folder.evm_object_class == :EmsFolder && !EmsFolder::NON_DISPLAY_FOLDERS.include?(folder.name)
      full_path += full_path.blank? ? "#{folder.name}" : " / #{folder.name}"
      dh[folder.id] = full_path unless folder.is_datacenter?
    end

    # Process child folders
    node = load_ems_node(folder, log_header)
    node.children.each { |child| get_ems_folders(child.attributes[:object], dh, full_path) } unless node.nil?

    dh
  end

  def get_ems_respool(node, dh = {}, full_path = "")
    if node.kind_of?(XmlHash::Element)
      folder = node.attributes[:object]
      if node.name == :ResourcePool
        full_path += full_path.blank? ? "#{folder.name}" : " / #{folder.name}"
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
    if hosts.blank?
      cluster = find_cluster_above_ci(item)
      hosts = find_hosts_under_ci(cluster)
    else
      hosts = [hosts]
    end
    hosts
  end

  def find_cluster_above_ci(item, ems_src = nil)
    find_class_above_ci(item, EmsCluster, ems_src)
  end

  def find_class_above_ci(item, klass, _ems_src = nil, datacenter = false)
    log_header = "MIQ(#{self.class.name}.find_class_above_ci)"
    result = nil
    node = load_ems_node(item, log_header)
    klass_name = klass.name.to_sym
    # Walk the xml document parents to find the requested class
    while node.kind_of?(XmlHash::Element)
      ci = node.attributes[:object]
      if node.name == klass_name && (datacenter == false || datacenter == true && ci.is_datacenter?)
        result = ci
        break
      end
      node = node.parent
    end

    result
  end

  def each_ems_metadata(ems_ci = nil, klass = nil, &_blk)
    log_header = "MIQ(#{self.class.name}.each_ems_metadata)"
    if ems_ci.nil?
      src = get_source_and_targets
      ems_xml = get_ems_metadata_tree(src)
      ems_node = ems_xml.root
    else
      ems_node = load_ems_node(ems_ci, log_header)
    end
    klass_name = klass.name.to_sym unless klass.nil?
    unless ems_node.nil?
      ems_node.each_recursive { |node| yield(node.attributes[:object]) if klass.nil? || klass_name == node.name }
    end
  end

  def get_ems_metadata_tree(src)
    @ems_metadata_tree ||= begin
      log_header = "MIQ(#{self.class.name}.get_ems_metadata_tree)"
      st = Time.now
      rails_logger('get_ems_metadata_tree', 0)
      result = load_ar_obj(src[:ems]).fulltree_arranged(:except_type => "VmOrTemplate")
      ems_metadata_tree_add_hosts_under_clusters!(result)
      rails_logger("get_ems_metadata_tree completed in [#{Time.now - st}] seconds.  ", 1)
      @ems_xml_nodes = {}
      xml = MiqXml.newDoc(:xmlhash)
      convert_to_xml(xml, result)
      $log.info "#{log_header} Load EMS metadata for: <#{@ems_xml_nodes.keys.inspect}>"
      $log.info "#{log_header} EMS metadata collection completed in [#{Time.now - st}] seconds"
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
    result[key] = ci_to_hash_struct(klass.find_by_id(result[key_id])) unless result[key_id].nil?
  end

  def ci_to_hash_struct(ci)
    return ci.collect { |c| ci_to_hash_struct(c) } if ci.kind_of?(Array)
    method_name = "#{ci.class.base_class.name.underscore}_to_hash_struct".to_sym
    return send(method_name, ci) if respond_to?(method_name, true)
    default_ci_to_hash_struct(ci)
  end

  def host_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :vmm_product, :vmm_version, :state, :v_total_vms])
  end

  def vm_or_template_to_hash_struct(ci)
    v = build_ci_hash_struct(ci, [:name, :platform])
    v.snapshots = ci.snapshots.collect { |si| ci_to_hash_struct(si) }
    v
  end

  def default_ci_to_hash_struct(ci)
    attributes = []
    attributes << :name if ci.respond_to?(:name)
    build_ci_hash_struct(ci, attributes)
  end

  def ems_folder_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :is_datacenter?])
  end

  def storage_to_hash_struct(ci)
    build_ci_hash_struct(ci, [:name, :free_space, :total_space, :storage_domain_type])
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
    ci.evm_object_class.to_s.camelize.constantize.find_by_id(ci.id)
  end

  def load_ar_objs(ci)
    ci.collect { |i| load_ar_obj(i) }
  end

  # Return empty hash if we are selecting placement automatically so we do not
  # send time determining all the available resources
  def resources_for_ui
    get_source_and_targets
  end

  def allowed_hosts_obj(_options = {})
    log_header = "MIQ(#{self.class.name}.allowed_hosts_obj)"
    return [] if (src = resources_for_ui).blank?

    rails_logger('allowed_hosts_obj', 0)
    st = Time.now
    hosts_ids = find_all_ems_of_type(Host).collect(&:id)
    hosts_ids &= load_ar_obj(src[:storage]).hosts.collect(&:id) unless src[:storage].nil?
    unless src[:datacenter].nil?
      dc_node = load_ems_node(src[:datacenter], log_header)
      hosts_ids &= find_hosts_under_ci(dc_node.attributes[:object]).collect(&:id)
    end
    return [] if hosts_ids.blank?

    # Remove any hosts that are no longer in the list
    all_hosts = load_ar_obj(src[:ems]).hosts.find_all { |h| hosts_ids.include?(h.id) }
    allowed_hosts_obj_cache = process_filter(:host_filter, Host, all_hosts)
    $log.info "MIQ(#{self.class.name}#allowed_hosts_obj) allowed_hosts_obj returned [#{allowed_hosts_obj_cache.length}] objects in [#{Time.now - st}] seconds"
    rails_logger('allowed_hosts_obj', 1)
    allowed_hosts_obj_cache
  end

  def allowed_storages(_options = {})
    return [] if (src = resources_for_ui).blank?
    hosts = src[:host].nil? ? allowed_hosts_obj({}) : [load_ar_obj(src[:host])]
    return [] if hosts.blank?

    rails_logger('allowed_storages', 0)
    st = Time.now
    MiqPreloader.preload(hosts, :storages)

    storage_ids = []
    storages = hosts.inject([]) do |a, h|
      h.storages.each do |s|
        unless storage_ids.include?(s.id)
          a << s
          storage_ids << s.id
        end
      end
      a
    end

    allowed_storages_cache = process_filter(:ds_filter, Storage, storages).collect do |s|
      ci_to_hash_struct(s)
    end

    $log.info "MIQ(#{self.class.name}#allowed_storages) allowed_storages returned [#{allowed_storages_cache.length}] objects in [#{Time.now - st}] seconds"
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
    filtered_targets = process_filter_all(:cluster_filter, EmsCluster)
    filtered_ids = filtered_targets.collect(&:id)
    allowed_ci(:cluster, [:respool, :host, :folder], filtered_ids)
  end

  def allowed_respools(_options = {})
    filtered_targets = process_filter_all(:rp_filter, ResourcePool)
    filtered_ids = filtered_targets.collect(&:id)
    allowed_ci(:respool, [:cluster, :host, :folder], filtered_ids)
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
    sources.collect { |c| find_datacenter_for_ci(c) }.compact.uniq.inject({}) { |r, c| r[c.id] = c.name; r }
  end

  def respool_to_cluster(src)
    return nil unless ems_has_clusters?
    sources = src[:respool].nil? ? find_all_ems_of_type(ResourcePool) : [src[:respool]]
    targets = sources.collect { |rp| find_cluster_above_ci(rp) }.compact
    targets.inject({}) { |r, c| r[c.id] = c.name; r }
  end

  def host_to_cluster(src)
    return nil unless ems_has_clusters?
    sources = src[:host].nil? ? allowed_hosts_obj : [src[:host]]
    targets = sources.collect { |h| find_cluster_above_ci(h) }.compact
    targets.inject({}) { |r, c| r[c.id] = c.name; r }
  end

  def folder_to_cluster(src)
    return nil unless ems_has_clusters?
    source = find_all_ems_of_type(EmsCluster)
    # If a folder is selected, reduce the cluster list to only clusters in the same data center as the folder
    source = source.reject { |c| find_datacenter_for_ci(c).id != src[:datacenter].id } unless src[:datacenter].nil?
    source.inject({}) { |r, c| r[c.id] = c.name; r }
  end

  def cluster_to_respool(src)
    return nil unless ems_has_clusters?
    targets = src[:cluster].nil? ? find_all_ems_of_type(ResourcePool) : find_respools_under_ci(src[:cluster])
    res_pool_with_path = get_ems_respool(get_ems_metadata_tree(src))
    targets.inject({}) { |r, rp| r[rp.id] = res_pool_with_path[rp.id]; r }
  end

  def folder_to_respool(src)
    return nil if src[:folder_id].nil?
    datacenter = find_datacenter_for_ci(src[:folder])
    targets = find_respools_under_ci(datacenter)
    res_pool_with_path = get_ems_respool(get_ems_metadata_tree(src))
    targets.inject({}) { |r, rp| r[rp.id] = res_pool_with_path[rp.id]; r }
  end

  def host_to_respool(src)
    hosts = src[:host].nil? ? allowed_hosts_obj : [src[:host]]
    targets = hosts.collect do |h|
      cluster = find_cluster_above_ci(h)
      source = cluster.nil? ? h : cluster
      find_respools_under_ci(source)
    end.flatten
    res_pool_with_path = get_ems_respool(get_ems_metadata_tree(src))
    targets.inject({}) { |r, rp| r[rp.id] = res_pool_with_path[rp.id]; r }
  end

  def cluster_to_host(src)
    return nil unless ems_has_clusters?
    hosts = src[:cluster].nil? ? find_all_ems_of_type(Host) : find_hosts_under_ci(src[:cluster])
    hosts.inject({}) { |r, h| r[h.id] = h.name; r }
  end

  def respool_to_host(src)
    hosts = src[:respool].nil? ? find_all_ems_of_type(Host) : find_hosts_for_respool(src[:respool])
    hosts.inject({}) { |r, h| r[h.id] = h.name; r }
  end

  def folder_to_host(src)
    source = find_all_ems_of_type(Host)
    # If a folder is selected, reduce the host list to only hosts in the same datacenter as the folder
    source = source.reject { |h| find_datacenter_for_ci(h).id != src[:datacenter].id } unless src[:datacenter].nil?
    source.inject({}) { |r, h| r[h.id] = h.name; r }
  end

  def host_to_folder(src)
    sources = src[:host].nil? ? allowed_hosts_obj : [src[:host]]
    datacenters = sources.collect do |h|
      rails_logger("host_to_folder for host #{h.name}", 0)
      result = find_datacenter_for_ci(h)
      rails_logger("host_to_folder for host #{h.name}", 1)
      result
    end.compact
    folders = {}
    datacenters.each do |dc|
      rails_logger("host_to_folder for dc #{dc.name}", 0)
      folders.merge!(get_ems_folders(dc))
      rails_logger("host_to_folder for dc #{dc.name}", 1)
    end
    folders
  end

  def cluster_to_folder(src)
    return nil unless ems_has_clusters?
    return nil if src[:cluster].nil?
    sources = [src[:cluster]]
    datacenters = sources.collect { |h| find_datacenter_for_ci(h) }.compact
    folders = {}
    datacenters.each { |dc| folders.merge!(get_ems_folders(dc)) }
    folders
  end

  def respool_to_folder(src)
    return nil if src[:respool_id].nil?
    sources = [src[:respool]]
    datacenters = sources.collect { |h| find_datacenter_for_ci(h) }.compact
    folders = {}
    datacenters.each { |dc| folders.merge!(get_ems_folders(dc)) }
    folders
  end

  def set_ws_field_value(values, key, data, dialog_name, dlg_fields)
    log_header = "#{self.class.name}.set_field_value"
    value = data.delete(key)

    dlg_field = dlg_fields[key]
    data_type = dlg_field[:data_type]
    set_value = case data_type
    when :integer then value.to_i_with_method
    when :float   then value.to_f
    when :boolean then (value.to_s.downcase == 'true')
    when :time    then Time.parse(value)
    when :button  then value # Ignore
    else value # Ignore
    end

    result = nil
    if dlg_field.key?(:values)
      field_values = dlg_field[:values]
      $log.info "#{log_header} processing key <#{dialog_name}:#{key}(#{data_type})> with values <#{field_values.inspect}>"
      if field_values.present?
        result = if field_values.first.kind_of?(MiqHashStruct)
                   found = field_values.detect { |v| v.id == set_value }
                   [found.id, found.name] if found
                 else
                   [set_value, field_values[set_value]] if field_values.key?(set_value)
                 end

        set_value = [result.first, result.last] unless result.nil?
      end
    end

    $log.warn "#{log_header} Unable to find value for key <#{dialog_name}:#{key}(#{data_type})> with input value <#{set_value.inspect}>.  No matching item found." if result.nil?
    $log.info "#{log_header} setting key <#{dialog_name}:#{key}(#{data_type})> to value <#{set_value.inspect}>"
    values[key] = set_value
  end

  def set_ws_field_value_by_display_name(values, key, data, dialog_name, dlg_fields, obj_key = :name)
    log_header = "#{self.class.name}.set_ws_field_value_by_display_name"
    value = data.delete(key)

    dlg_field = dlg_fields[key]
    data_type = dlg_field[:data_type]
    find_value = value.to_s.downcase

    if dlg_field.key?(:values)
      field_values = dlg_field[:values]
      $log.info "#{log_header} processing key <#{dialog_name}:#{key}(#{data_type})> with values <#{field_values.inspect}>"
      if field_values.present?
        result = if field_values.first.kind_of?(MiqHashStruct)
                   found = field_values.detect { |v| v.send(obj_key).to_s.downcase == find_value }
                   [found.id, found.send(obj_key)] if found
                 else
                   field_values.detect { |_k, v| v.to_s.downcase == find_value }
                 end

        unless result.nil?
          set_value = [result.first, result.last]
          $log.info "#{log_header} setting key <#{dialog_name}:#{key}(#{data_type})> to value <#{set_value.inspect}>"
          values[key] = set_value
        else
          $log.warn "#{log_header} Unable to set key <#{dialog_name}:#{key}(#{data_type})> to value <#{find_value.inspect}>.  No matching item found."
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
    $log.info "#{self.class.name}##{__method__} <#{dialog_name}> dialog not found in dialogs.  Field updates will be skipped." if dlg_fields.nil?
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
    klass.constantize.find_by_id(id)
  end

  def get_pxe_server
    PxeServer.find_by_id(get_value(@values[:pxe_server_id]))
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
    template = VmOrTemplate.find_by_id(get_value(@values[:src_vm_id]))
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
    log_header = "MIQ(#{self.class.name}#ws_requester_fields)"
    dialog_name = :requester
    dlg_fields = @dialogs.fetch_path(:dialogs, :requester, :fields)
    if dlg_fields.nil?
      $log.info "#{log_header} <#{dialog_name}> dialog not found in dialogs.  Field updates be skipped."
      return
    end

    data = parse_ws_string(fields)
    $log.info "#{log_header} data:<#{data.inspect}>"
    values[:auto_approve] = data.delete(:auto_approve) == 'true'
    data.delete(:user_name)

    # get owner values from LDAP if configured
    if data[:owner_email].present? && MiqLdap.using_ldap?
      email = data[:owner_email]
      unless email.include?('@')
        suffix = VMDB::Config.new("vmdb").config[:authentication].fetch_path(:user_suffix)
        email = "#{email}@#{suffix}"
      end
      values[:owner_email] = email
      retrieve_ldap rescue nil
    end

    dlg_keys = dlg_fields.keys
    data.keys.each do |key|
      if dlg_keys.include?(key)
        $log.info "#{log_header} processing key <#{dialog_name}:#{key}> with value <#{data[key].inspect}>"
        values[key] = data[key]
      else
        $log.warn "#{log_header} Skipping key <#{dialog_name}:#{key}>.  Key name not found in dialog"
      end
    end
  end

  def ws_schedule_fields(values, _fields, data)
    log_header = "MIQ(#{self.class.name}#ws_schedule_fields)"
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :schedule)).nil?

    unless data[:schedule_time].blank?
      values[:schedule_type] = 'schedule'
      [:schedule_time, :retirement_time].each do |key|
        data_type = :time
        time_value = data.delete(key)
        set_value = time_value.blank? ? nil : Time.parse(time_value)
        $log.info "#{log_header} setting key <#{dialog_name}:#{key}(#{data_type})> to value <#{set_value.inspect}>"
        values[key] = set_value
      end
    end

    dlg_keys = dlg_fields.keys
    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key) }
  end

  def validate_values(values)
    if validate(values) == false
      log_header = "MIQ(#{self.class.name}#validate_values)"
      errors = []
      fields { |_fn, f, _dn, _d| errors << f[:error] unless f[:error].nil? }
      err_text = "Provision failed for the following reasons:\n#{errors.join("\n")}"
      $log.error "#{log_header}: <#{err_text}>"
      raise err_text
    end
  end
end
