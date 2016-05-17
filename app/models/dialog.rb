class Dialog < ApplicationRecord
  DIALOG_DIR = Rails.root.join("product/dialogs/service_dialogs")

  # The following gets around a glob symbolic link issue
  ALL_YAML_FILES = DIALOG_DIR.join("{,*/**/}*.{yaml,yml}")

  has_many :dialog_tabs, -> { order :position }, :dependent => :destroy
  validate :validate_children

  include DialogMixin
  include ReportableMixin
  has_many   :resource_actions
  virtual_has_one :content, :class_name => "Hash"

  before_destroy          :reject_if_has_resource_actions
  validates_uniqueness_of :label

  alias_attribute  :name, :label

  attr_accessor :target_resource

  def self.seed
    dialog_import_service = DialogImportService.new

    Dir.glob(ALL_YAML_FILES).each do |file|
      dialog_import_service.import_all_service_dialogs_from_yaml_file(file)
    end
  end

  def each_dialog_field(&block)
    dialog_fields.each(&block)
  end

  def dialog_fields
    dialog_tabs.flat_map(&:dialog_fields)
  end

  def field_name_exist?(name)
    dialog_fields.any? { |df| df.name == name }
  end

  def dialog_resources
    dialog_tabs
  end

  def automate_values_hash
    dialog_fields.each_with_object({}) { |df, result| result[df.automate_key_name] = df.automate_output_value }
  end

  def validate_children
    # To remove the meaningless error message like "Dialog tabs is invalid" when child's validation fails
    errors[:dialog_tabs].delete("is invalid")
    errors.add(:base, "Dialog #{label} must have at least one Tab") if dialog_tabs.blank?

    dialog_tabs.each do |dt|
      next if dt.valid?
      dt.errors.full_messages.each do |err_msg|
        errors.add(:base, "Dialog #{label} / #{err_msg}")
      end
    end
  end

  def validate_field_data
    result = []
    dialog_tabs.each do |dt|
      dt.dialog_groups.each do |dg|
        dg.dialog_fields.each do |df|
          err_msg = df.validate_field_data(dt, dg)
          result << err_msg unless err_msg.blank?
        end
      end
    end
    result
  end

  def init_fields_with_values(values)
    dialog_field_hash.each do |key, field|
      values[key] = field.value
      field.dialog   = self
    end
    dialog_field_hash.each { |key, field| values[key] = field.initialize_with_values(values) }
    dialog_field_hash.each { |_key, field| field.update_values(values) }
  end

  def field(name)
    dialog_field_hash[name.to_s]
  end

  def content(target = nil, resource_action = nil)
    return DialogSerializer.new.serialize(Array[self]) if target.nil? && resource_action.nil?

    workflow = ResourceActionWorkflow.new({}, @auth_user_obj, resource_action, :target => target)

    workflow.dialog.dialog_fields.each do |dialog_field|
      # Accessing dialog_field.values forces an update for any values coming from automate
      dialog_field.values = dialog_field.values
    end
    DialogSerializer.new.serialize(Array[workflow.dialog])
  end

  private

  def dialog_field_hash
    @dialog_field_hash ||= dialog_fields.each_with_object({}) { |df, hash| hash[df.name] = df }
  end

  def reject_if_has_resource_actions
    if resource_actions.length > 0
      raise _("Dialog cannot be deleted because it is connected to other components.")
    end
  end
end
