module DialogMixin
  extend ActiveSupport::Concern

  included do
    validates_presence_of   :label
  end

  def add_resource(rsc, options={})
    dr = self.dialog_resources.detect{|r| r.id == rsc.id}
    if dr.nil?
      rsc.update_attributes(options)
      self.dialog_resources << rsc
      dr = rsc
    end
    return dr
  end

  def add_resource!(rsc, options={})
    self.add_resource(rsc, options)
    self.save!
  end

  def remove_all_resources
    self.dialog_resources.destroy_all
  end

  def ordered_dialog_resources
    self.dialog_resources.sort_by {|a| a.order.to_i}
  end

  def resource
    self
  end

end
