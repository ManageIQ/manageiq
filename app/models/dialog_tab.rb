class DialogTab < ApplicationRecord
  include DialogMixin
  has_many   :dialog_groups, -> { order(:position) }, :dependent => :destroy
  belongs_to :dialog
  validate :validate_children

  alias_attribute :order, :position

  def each_dialog_field(&block)
    dialog_fields.each(&block)
  end

  def dialog_fields
    dialog_groups.flat_map(&:dialog_fields)
  end

  def dialog_resources
    dialog_groups
  end

  def validate_children
    errors[:dialog_groups].delete("is invalid")
    errors.add(:base, _("Tab %{tab_label} must have at least one Box") % {:tab_label => label}) if dialog_groups.blank?

    dialog_groups.each do |dg|
      next if dg.valid?
      dg.errors.full_messages.each do |err_msg|
        errors.add(:base, _("Tab %{tab_label} / %{error_message}") % {:tab_label => label, :error_message => err_msg})
      end
    end
  end

  def update_dialog_groups(groups)
    updated_groups = []
    groups.each do |group|
      if group.key?('id')
        DialogGroup.find(group['id']).tap do |dialog_group|
          dialog_group.update(group.except('id', 'href', 'dialog_tab_id', 'dialog_fields'))
          dialog_group.update_dialog_fields(group['dialog_fields'])
          updated_groups << dialog_group
        end
      else
        updated_groups << DialogImportService.new.build_dialog_groups('dialog_groups' => [group]).first
      end
    end
    self.dialog_groups = updated_groups
  end

  def deep_copy
    dup.tap do |new_tab|
      new_tab.dialog_groups = dialog_groups.collect(&:deep_copy)
    end
  end
end
