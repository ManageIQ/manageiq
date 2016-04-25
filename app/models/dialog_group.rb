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

  def validate_children
    errors.add(:base, "Box #{label} must have at least one Element") if dialog_fields.blank?

    dialog_fields.each do |df|
      next if df.valid?
      df.errors.full_messages.each do |err_msg|
        errors.add(:base, "Box #{label} / #{err_msg}")
      end
    end
  end
end
