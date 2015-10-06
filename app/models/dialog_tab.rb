class DialogTab < ActiveRecord::Base
  include DialogMixin
  has_many   :dialog_groups, -> { order(:position) }, :dependent => :destroy
  belongs_to :dialog

  alias_attribute :order, :position

  def to_h
    [name.to_sym, values_to_h]
  end

  def values_to_h
    result = {}
    ordered_dialog_resources
    result
  end

  def each_dialog_field
    dialog_groups.each { |dg| dg.each_dialog_field { |df| yield(df) } }
  end

  def dialog_fields
    dialog_groups.collect(&:dialog_fields).flatten!
  end

  def dialog_resources
    dialog_groups
  end
end
