class DialogGroup < ApplicationRecord
  include DialogMixin
  has_many   :dialog_fields, -> { order(:position) }, :dependent => :destroy
  belongs_to :dialog_tab
  validate :validate_children

  alias_attribute :order, :position

  def each_dialog_field(&block)
    dialog_fields.each(&block)
  end

  def dialog_resources
    dialog_fields
  end

  def update_dialog_fields(fields)
    updated_fields = []
    fields.each do |field|
      field['options'].try(:symbolize_keys!)
      if field.key?('id')
        DialogField.find(field['id']).tap do |dialog_field|
          resource_action_fields = field.delete('resource_action') || {}
          update_resource_fields(resource_action_fields, dialog_field)
          dialog_field.update(field.except('id', 'href', 'dialog_group_id', 'dialog_field_responders'))
          updated_fields << dialog_field
        end
      else
        updated_fields << DialogImportService.new.build_dialog_fields('dialog_fields' => [field]).first
      end
    end
    self.dialog_fields = updated_fields
  end

  def validate_children
    if dialog_fields.blank?
      errors.add(:base, _("Box %{box_label} must have at least one Element") % {:box_label => label})
    end

    dialog_fields.each do |df|
      next if df.valid?
      df.errors.full_messages.each do |err_msg|
        errors.add(:base, _("Box %{box_label} / %{error_message}") % {:box_label => label, :error_message => err_msg})
      end
    end
  end

  def deep_copy
    dup.tap do |new_group|
      new_group.dialog_fields = dialog_fields.collect(&:deep_copy)
    end
  end

  private

  def update_resource_fields(resource_action_fields, dialog_field)
    if resource_action_fields.key?('id')
      dialog_field.resource_action.update(resource_action_fields.except('id'))
    elsif resource_action_fields.present?
      dialog_field.resource_action = ResourceAction.create(resource_action_fields)
    end
  end
end
