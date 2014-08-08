class DialogField < ActiveRecord::Base
  attr_accessor :value
  attr_accessor :dialog

  belongs_to :dialog_group

  alias_attribute :order, :position

  validates_presence_of   :name
  validates :name, exclusion: { in: %w(action controller),
    message: "Field Name %{value} is reserved." }

  default_value_for :required, false

  serialize :values
  serialize :values_method_options,   Hash
  serialize :display_method_options,  Hash
  serialize :required_method_options, Hash
  serialize :options,                 Hash

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
    "DialogFieldTextBox"         => "Text Box",
    "DialogFieldTextAreaBox"     => "Text Area Box",
    "DialogFieldCheckBox"        => "Check Box",
    "DialogFieldDropDownList"    => "Drop Down List",
# Commented out next to field types until they can be implemented
#    "DialogFieldButton" => "Button",
    "DialogFieldTagControl"      => "Tag Control",
    "DialogFieldDateControl"     => "Date Control",
    "DialogFieldDateTimeControl" => "Date/Time Control",
    "DialogFieldRadioButton"     => "Radio Button",
    "DialogFieldDynamicList"     => "Drop Down Dynamic List",
  }

  def self.dialog_field_types
    DIALOG_FIELD_TYPES
  end

  def self.field_types
    FIELD_CONTROLS
  end

  def initialize_with_values(dialog_values)
    @value = value_from_dialog_fields(dialog_values) || get_default_value
  end

  def update_values(dialog_values)
    # override in subclasses
    nil
  end

  def automate_output_value
    @value
  end

  def automate_key_name
    "dialog_#{self.name}"
  end

  def validate(dialog_tab, dialog_group)
    if self.required?
      return "#{dialog_tab.label}/#{dialog_group.label}/#{self.label} is required" if self.value.blank?
    end
  end

  def resource
    self
  end

  private

  def value_from_dialog_fields(dialog_values)
    dialog_values[automate_key_name]
  end

  def get_default_value
    self.default_value
  end
end
