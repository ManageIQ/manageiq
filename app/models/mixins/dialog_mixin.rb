module DialogMixin
  extend ActiveSupport::Concern

  included do
    validates_presence_of   :label
  end

  def remove_all_resources
    dialog_resources.destroy_all
  end

  def ordered_dialog_resources
    dialog_resources.sort_by { |a| a.order.to_i }
  end

  def resource
    self
  end
end
