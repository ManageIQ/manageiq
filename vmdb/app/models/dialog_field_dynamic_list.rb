class DialogFieldDynamicList < DialogFieldDropDownList

  has_one       :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

  def values_from_automate
    dialog_values = {:dialog => @dialog.try(:automate_values_hash)}
    ws = self.resource_action.deliver_to_automate_from_dialog_field(dialog_values, @dialog.try(:target_resource))
    process_automate_values(ws.root.attributes)
  rescue => err
    [[nil, "<Script error>"]]
  end

  def process_automate_values(ws_attrs)
    %w{sort_by sort_order data_type default_value}.each do |key|
      self.send("#{key}=", ws_attrs[key]) if ws_attrs.has_key?(key)
    end

    self.required = (ws_attrs["required"].to_s.downcase == "true") if ws_attrs.has_key?("required")
    normalize_automate_values(ws_attrs["values"])
  end

  def normalize_automate_values(ae_values)
    result = ae_values.to_a
    result.blank? ? initial_values : result
  end

  def initial_values
    [[nil, "<None>"]]
  end

  def raw_values
    return @raw_values if @raw_values
    @raw_values = values_from_automate
  end

  def refresh_button_pressed
    @raw_values = default_value = nil
    values
  end

  def default_resource_action
    build_resource_action if self.resource_action.nil?
  end

  def initialize_with_values(dialog_values)
    if load_values_on_init?
      raw_values
      @value = value_from_dialog_fields(dialog_values) || self.get_default_value
    else
      @raw_values = initial_values
    end
  end

  def load_values_on_init?
    return true if self.options[:show_refresh_button] == false
    !!self.options[:load_values_on_init]
  end

  def show_refresh_button
    self.options[:show_refresh_button] || false
  end

  def show_refresh_button=(value)
    self.options[:show_refresh_button] = value
  end

  def load_values_on_init
    self.options[:load_values_on_init] || false
  end

  def load_values_on_init=(value)
    self.options[:load_values_on_init] = value
  end

  # Determines whether we have to show the refresh button in the UI
  def show_refresh_button?
    show_refresh_button || !self.load_values_on_init?
  end
end
