class Dialog < ActiveRecord::Base
  DIALOG_DIR = Rails.root.join("product/dialogs/service_dialogs")

  # The following gets around a glob symbolic link issue
  ALL_YAML_FILES = DIALOG_DIR.join("{,*/**/}*.{yaml,yml}")

  has_many :dialog_tabs, -> { order :position }, :dependent => :destroy

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

  def each_dialog_field
    dialog_tabs.each { |dt| dt.each_dialog_field { |df| yield(df) } }
  end

  def dialog_fields
    dialog_tabs.collect(&:dialog_fields).flatten!
  end

  def field_name_exist?(name)
    each_dialog_field { |df| return true if df.name == name }
    false
  end

  def dialog_resources
    dialog_tabs
  end

  def automate_values_hash
    result = {}
    each_dialog_field { |df| result[df.automate_key_name] = df.automate_output_value }
    result
  end

  def validate
    result = []
    dialog_tabs.each do |dt|
      dt.dialog_groups.each do |dg|
        dg.dialog_fields.each do |df|
          err_msg = df.validate(dt, dg)
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

  def content
    DialogSerializer.new.serialize(Array[self])
  end

  private

  def dialog_field_hash
    @dialog_field_hash ||= begin
      hash = {}
      each_dialog_field { |df| hash[df.name] = df }
      hash
    end
  end

  def reject_if_has_resource_actions
    raise "Dialog cannot be deleted because it is connected to other components." if resource_actions.length > 0
  end
end
