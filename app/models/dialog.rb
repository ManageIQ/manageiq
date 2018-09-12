class Dialog < ApplicationRecord
  DIALOG_DIR_PLUGIN = 'content/service_dialogs'.freeze

  # The following gets around a glob symbolic link issue
  YAML_FILES_PATTERN = "{,*/**/}*.{yaml,yml}".freeze

  has_many :dialog_tabs, -> { order(:position) }, :dependent => :destroy
  validate :validate_children

  include DialogMixin
  has_many :resource_actions
  virtual_has_one :content, :class_name => "Hash"

  before_destroy :reject_if_has_resource_actions
  validates      :name, :unique_within_region => true

  alias_attribute  :name, :label

  attr_accessor :target_resource

  def self.seed
    dialog_import_service = DialogImportService.new

    Vmdb::Plugins.each do |plugin|
      Dir.glob(plugin.root.join(DIALOG_DIR_PLUGIN, YAML_FILES_PATTERN)).each do |file|
        dialog_import_service.import_all_service_dialogs_from_yaml_file(file)
      end
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
    dialog_fields.each_with_object({}) do |df, result|
      if df.options.include?("multiple")
        result[MiqAeEngine.create_automation_attribute_array_key(df.automate_key_name)] = df.automate_output_value
      else
        result[df.automate_key_name] = df.automate_output_value
      end
    end
  end

  def validate_children
    # To remove the meaningless error message like "Dialog tabs is invalid" when child's validation fails
    errors[:dialog_tabs].delete("is invalid")
    if dialog_tabs.blank?
      errors.add(:base, _("Dialog %{dialog_label} must have at least one Tab") % {:dialog_label => label})
    end

    duplicate_field_names = dialog_fields.collect(&:name).duplicates
    if duplicate_field_names.present?
      errors.add(:base, _("Dialog field name cannot be duplicated on a dialog: %{duplicates}") % {:duplicates => duplicate_field_names.join(', ')})
    end

    dialog_tabs.each do |dt|
      next if dt.valid?
      dt.errors.full_messages.each do |err_msg|
        errors.add(:base, _("Dialog %{dialog_label} / %{error_message}") %
                   {:dialog_label => label, :error_message => err_msg})
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

  def load_values_into_fields(values, overwrite = true)
    values = values.with_indifferent_access

    dialog_field_hash.each_value do |field|
      field.dialog = self
      new_value = values[field.automate_key_name] || values[field.name] || values.dig("parameters", field.name)
      new_value ||= field.value unless overwrite

      field.value = new_value
    end
  end

  def initialize_with_given_values(values)
    dialog_field_hash.each_value do |field|
      field.dialog = self
      field.value = values[field.automate_key_name] || values[field.name]
    end

    dialog_field_hash.each_value do |field|
      given_value = values[field.automate_key_name] || values[field.name]
      field.initialize_with_given_value(given_value)
    end
  end

  def initialize_value_context(_values)
    dialog_field_hash.each_value do |field|
      field.dialog = self
    end

    dialog_field_hash.each_value(&:initialize_value_context)
  end

  def init_fields_with_values_for_request(values)
    dialog_field_hash.each do |_key, field|
      field.value = values[field.automate_key_name] || values[field.name]
    end
  end

  def field(name)
    dialog_field_hash[name.to_s]
  end

  def content(target = nil, resource_action = nil, all_attributes = false)
    return DialogSerializer.new.serialize(Array[self], all_attributes) if target.nil? && resource_action.nil?

    workflow = ResourceActionWorkflow.new({}, User.current_user, resource_action, :target => target)

    DialogSerializer.new.serialize(Array[workflow.dialog], all_attributes)
  end

  # Allows you to pass dialog tabs as a hash
  # Will update any item passed with an ID,
  # Creates a new item without an ID,
  # Removes any items not passed in the content.
  def update_tabs(tabs)
    association_list = dialog_import_service.build_association_list("dialog_tabs" => tabs)

    transaction do
      updated_tabs = []
      tabs.each do |dialog_tab|
        if dialog_tab.key?('id')
          DialogTab.find(dialog_tab['id']).tap do |tab|
            tab.update_attributes(dialog_tab.except('id', 'href', 'dialog_id', 'dialog_groups'))
            tab.update_dialog_groups(dialog_tab['dialog_groups'])
            updated_tabs << tab
          end
        else
          updated_tabs << dialog_import_service.build_dialog_tabs('dialog_tabs' => [dialog_tab]).first
        end
      end
      self.dialog_tabs = updated_tabs
    end

    transaction do
      dialog_import_service.build_associations(self, association_list)
    end
  end

  def deep_copy(new_attributes = {})
    new_dialog = dup
    new_dialog.dialog_tabs = dialog_tabs.collect(&:deep_copy)

    new_attributes.each do |attr, value|
      new_dialog.send("#{attr}=", value)
    end
    new_dialog
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

  def dialog_import_service
    @dialog_import_service ||= DialogImportService.new
  end
end
