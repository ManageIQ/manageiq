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
      @value = value_from_dialog_fields(dialog_values) || default_value
    else
      @raw_values = initial_values
    end
  end

  def show_refresh_button?
    !!show_refresh_button
  end

  def initial_values
    [["", "<None>"]]
  end

  private

  def load_values_on_init?
    return true unless show_refresh_button
    load_values_on_init
  end

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def raw_values
    if dynamic
      @raw_values = values_from_automate
    else
      @raw_values = super
    end
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
