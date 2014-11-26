class DialogFieldRadioButton < DialogFieldSortedItem
  has_one :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

  def refresh_button_pressed
    @raw_values = @default_value = nil
    values
  end

  def initialize_with_values(dialog_values)
    if load_values_on_init?
      raw_values
      @value = value_from_dialog_fields(dialog_values) || @default_value
    else
      @raw_values = initial_values
    end
  end

  def show_refresh_button
    options[:show_refresh_button] || false
  end

  def show_refresh_button=(value)
    options[:show_refresh_button] = value
  end

  def load_values_on_init
    options[:load_values_on_init] || false
  end

  def load_values_on_init=(value)
    options[:load_values_on_init] = value
  end

  def show_refresh_button?
    !!show_refresh_button
  end

  private

  def load_values_on_init?
    return true if options[:show_refresh_button] == false
    !!options[:load_values_on_init]
  end

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def initial_values
    [["", "<None>"]]
  end

  def raw_values
    if dynamic
      @raw_values ||= values_from_automate
    else
      @raw_values = super
    end
  end

  def values_from_automate
    dialog_values = {:dialog => @dialog.try(:automate_values_hash)}
    workspace = resource_action.deliver_to_automate_from_dialog_field(dialog_values, @dialog.try(:target_resource))
    process_automate_values(workspace.root.attributes)
  rescue
    [[nil, "<Script error>"]]
  end

  def process_automate_values(workspace_attributes)
    %w(sort_by sort_order data_type default_value).each do |key|
      send("#{key}=", workspace_attributes[key]) if workspace_attributes.key?(key)
    end

    @required = (workspace_attributes["required"].to_s.downcase == "true") if workspace_attributes.key?("required")
    normalize_automate_values(workspace_attributes["values"])
  end

  def normalize_automate_values(ae_values)
    result = ae_values.to_a
    result.blank? ? initial_values : result
  end
end
