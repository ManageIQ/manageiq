class DialogFieldDynamicList < DialogFieldDropDownList
  has_one       :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end

  def initial_values
    [[nil, "<None>"]]
  end

  def raw_values
    return @raw_values if @raw_values
    @raw_values = values_from_automate
  end

  def refresh_button_pressed
    @raw_values = @default_value = nil
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
    return true if show_refresh_button == false
    load_values_on_init
  end

  # Determines whether we have to show the refresh button in the UI
  def show_refresh_button?
    show_refresh_button || !self.load_values_on_init?
  end
end
