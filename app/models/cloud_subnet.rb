class CloudSubnet < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :availability_zone
  has_many   :vms

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes
end
