class DialogGroup < ActiveRecord::Base
  include DialogMixin
  has_many   :dialog_fields, :dependent => :destroy, :order => :position
  belongs_to :dialog_tab

  alias_attribute :order, :position

  def each_dialog_field
    self.dialog_fields.each {|df| yield(df)}
  end

  def dialog_resources
    self.dialog_fields
  end

end
