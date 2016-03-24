class DialogField < ApplicationRecord
  include NewWithTypeStiMixin
  attr_accessor :value
  attr_accessor :dialog

  belongs_to :dialog_group
  has_one :resource_action, :as => :resource, :dependent => :destroy

  alias_attribute :order, :position

  validates_presence_of   :name
  validates :name, :exclusion => {:in      => %w(action controller),
                                  :message => "Field Name %{value} is reserved."}

  default_value_for :required, false

  serialize :values
  serialize :values_method_options,   Hash
  serialize :display_method_options,  Hash
  serialize :required_method_options, Hash
  serialize :options,                 Hash

  after_initialize :default_resource_action

  # Sample data from V4 dialog.rb files
  # :data_type          # => :string / :integer / :button / :boolean / :time
  # :notes_display      # => :show / :hide
  # :display            # => :edit / :hide / :show / :ignore
  # :display_options    # => {:method => ???, :options => {???}}
  # :values             # => {false => 0, true => 1}
  # :values_options     # => {:category => :Vm}

  FIELD_CONTROLS = [
    :dialog_field_text_box,
    :dialog_field_text_area_box,
    :dialog_field_check_box,
    :dialog_field_drop_down_list,
    :dialog_field_button,
    :dialog_field_tag_control,
    :dialog_field_radio_button,
    :dialog_field_dynamic_list,
    # Enable when UI support is available
    # #:dialog_field_list_view      # Future
  ]

  DIALOG_FIELD_TYPES = {
    "DialogFieldTextBox"         => _("Text Box"),
    "DialogFieldTextAreaBox"     => _("Text Area Box"),
    "DialogFieldCheckBox"        => _("Check Box"),
    "DialogFieldDropDownList"    => _("Drop Down List"),
    # Commented out next to field types until they can be implemented
    #    "DialogFieldButton" => "Button",
    "DialogFieldTagControl"      => _("Tag Control"),
    "DialogFieldDateControl"     => _("Date Control"),
    "DialogFieldDateTimeControl" => _("Date/Time Control"),
    "DialogFieldRadioButton"     => _("Radio Button")
  }

  DIALOG_FIELD_DYNAMIC_CLASSES = %w(
    DialogFieldCheckBox
    DialogFieldDateControl
    DialogFieldDateTimeControl
    DialogFieldDropDownList
    DialogFieldRadioButton
    DialogFieldTextAreaBox
    DialogFieldTextBox
  )

  def self.dialog_field_types
    DIALOG_FIELD_TYPES
  end

  def self.field_types
    FIELD_CONTROLS
  end

  def initialize_with_values(dialog_values)
    @value = value_from_dialog_fields(dialog_values) || get_default_value
  end

  def update_values(_dialog_values)
    # override in subclasses
    nil
  end

  def normalize_automate_values(_passed_in_values)
    # override in subclasses
    nil
  end

  def automate_output_value
    data_type == "integer" ? @value.to_i : @value
  end

  def automate_key_name
    "dialog_#{name}"
  end

  def validate_field_data(dialog_tab, dialog_group)
    validate_error_message(dialog_tab, dialog_group) if required? && required_value_error?
  end

  def resource
    self
  end

  def update_and_serialize_values
    DialogFieldSerializer.serialize(self)
  end

  private

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def validate_error_message(dialog_tab, dialog_group)
    "#{dialog_tab.label}/#{dialog_group.label}/#{label} is required"
  end

  def required_value_error?
    value.blank?
  end

  def value_from_dialog_fields(dialog_values)
    dialog_values[automate_key_name] || dialog_values[name]
  end

  def get_default_value
    default_value
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
