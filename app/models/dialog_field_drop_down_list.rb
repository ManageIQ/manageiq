class DialogFieldDropDownList < DialogFieldSortedItem
  def initialize_with_given_value(given_value)
    super
    coerce_default_value_into_proper_format if force_multi_value
  end

  def show_refresh_button?
    !!show_refresh_button
  end

  def force_multi_value
    return true if options[:force_multi_value].present? &&
                   options[:force_multi_value] != "null" &&
                   options[:force_multi_value]
  end

  def force_multi_value=(setting)
    options[:force_multi_value] = setting
  end

  def initial_values
    [[nil, N_("<None>")]]
  end

  def refresh_json_value(checked_value)
    self.default_value = nil
    @raw_values = nil

    refreshed_values = values

    selectbox_options = refreshed_values.collect { |value_pair| value_pair[0].to_s }

    @value = if checked_value.kind_of?(Array) && (selectbox_options & checked_value).present?
               # if checked value is [1,2,4] and the intersection is [1,2], removes non-valid option 4
               # and does final check to make sure it's not returning [], otherwise, defaults
               selectbox_options & checked_value
             elsif selectbox_options.include?(checked_value)
               # checks if [1,2,3].includes?(3)
               checked_value
             else
               default_value
             end
    {:refreshed_values => refreshed_values, :checked_value => @value, :read_only => read_only?, :visible => visible?}
  end

  def automate_output_value
    return super unless force_multi_value
    a = if @value.kind_of?(Integer)
          [@value]
        elsif @value.kind_of?(Array)
          @value
        else
          @value.blank? ? [] : @value.chomp.split(',')
        end
    automate_values = a.first.kind_of?(Integer) ? a.map(&:to_i) : a
    MiqAeEngine.create_automation_attribute_array_value(automate_values)
  end

  def automate_key_name
    return super unless force_multi_value
    MiqAeEngine.create_automation_attribute_array_key(super)
  end

  private

  def determine_selected_value
    coerce_default_value_into_proper_format if dynamic? && force_multi_value

    super
  end

  def use_first_value_as_default
    self.default_value = if force_multi_value
                           [].to_json
                         else
                           sort_data(@raw_values).first.try(:first)
                         end
  end

  def default_value_included?(values_list)
    if force_multi_value
      return false if default_value.blank?
      converted_values_list = values_list.collect { |value_pair| value_pair[0].send(value_modifier) }
      converted_default_values = JSON.parse(default_value).collect { |value| value.send(value_modifier) }
      overlap = converted_values_list & converted_default_values
      !overlap.empty?
    else
      super(values_list)
    end
  end

  def coerce_default_value_into_proper_format
    return unless default_value
    unless JSON.parse(default_value).kind_of?(Array)
      self.default_value = Array.wrap(default_value).to_json
    end
  rescue JSON::ParserError
    self.default_value = Array.wrap(default_value).to_json
  end
end
