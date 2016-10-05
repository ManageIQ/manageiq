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
    existing_items = dialog_fields.pluck(:id)
    fields.each do |field|
      if field.key?('id')
        existing_items.delete(group['id'])
        DialogField.find(field['id']).tap do |dialog_field|
          dialog_field.update_attributes(field)
        end
      end
    end
    DialogField.where(:id => existing_items).each(&:destroy)
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
end
