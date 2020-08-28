class DialogField < ApplicationRecord
  include NewWithTypeStiMixin
  attr_accessor :value
  attr_accessor :dialog

  belongs_to :dialog_group
  has_one :resource_action, :as => :resource, :dependent => :destroy

  has_many :dialog_field_associations,
           :foreign_key => :trigger_id,
           :class_name  => :DialogFieldAssociation,
           :dependent   => :destroy
  has_many :reverse_dialog_field_associations,
           :foreign_key => :respond_id,
           :class_name  => :DialogFieldAssociation,
           :dependent   => :destroy

  has_many :dialog_field_responders,
           :source  => :respond,
           :through => :dialog_field_associations
  has_many :dialog_field_triggers,
           :source  => :trigger,
           :through => :reverse_dialog_field_associations

  alias_attribute :order, :position

  validates_presence_of   :name
  validates :name, :exclusion => {:in      => %w(action controller),
                                  :message => "Field Name %{value} is reserved."}

  default_value_for :required, false
  default_value_for(:visible) { true }
  validates :visible, inclusion: { in: [ true, false ] }
  default_value_for :load_values_on_init, true

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
    :dialog_field_tag_control,
    :dialog_field_radio_button
  ]

  DIALOG_FIELD_TYPES = {
    "DialogFieldTextBox"         => N_("Text Box"),
    "DialogFieldTextAreaBox"     => N_("Text Area Box"),
    "DialogFieldCheckBox"        => N_("Check Box"),
    "DialogFieldDropDownList"    => N_("Drop Down List"),
    "DialogFieldTagControl"      => N_("Tag Control"),
    "DialogFieldDateControl"     => N_("Date Control"),
    "DialogFieldDateTimeControl" => N_("Date/Time Control"),
    "DialogFieldRadioButton"     => N_("Radio Button")
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

  def extract_dynamic_values
    value
  end

  def initialize_value_context
    if @value.blank?
      @value = dynamic ? values_from_automate : default_value
    end
  end

  def initialize_static_values
    if @value.blank? && !dynamic
      @value = default_value
    end
  end

  def initialize_with_given_value(given_value)
    self.default_value = given_value
  end

  def initialize_with_values(dialog_values)
    # override in subclasses
    nil
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
    validate_error_message(dialog_tab, dialog_group) if visible? && required? && required_value_error?
  end

  def resource
    self
  end

  def update_and_serialize_values
    trigger_automate_value_updates
    DialogFieldSerializer.serialize(self)
  end

  def trigger_automate_value_updates
    @value = values_from_automate
  end

  def update_dialog_field_responders(id_list)
    dialog_field_responders.destroy_all

    self.dialog_field_responders = available_dialog_field_responders(id_list) unless id_list.blank?
  end

  def deep_copy
    dup.tap do |new_field|
      new_field.resource_action = resource_action.dup
    end
  end

  private

  def available_dialog_field_responders(id_list)
    DialogField.find(id_list)
  end

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

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
