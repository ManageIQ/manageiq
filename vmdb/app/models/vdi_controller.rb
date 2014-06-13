class VdiController < ActiveRecord::Base
  belongs_to :vdi_farm
  has_many   :vdi_sessions
  has_many   :ems_events

  virtual_column :vendor,  :type => :string,  :uses => :vdi_farm

  include ReportableMixin
  include ArCountMixin

  def vendor
    self.vdi_farm.nil? ? "unknown" : self.vdi_farm.vendor
  end
end
