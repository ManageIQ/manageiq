#
# A hub to centralize the Physical Components relationships.
#   and a common way to access the Physical Components.
#
# Physical Components:
#   - Physical Server;
#   - Physical Switch;
#   - Physical Chassis;
#   - Physical Rack.
#
class PhysicalComponent < ApplicationRecord
  belongs_to :component, :polymorphic => true

  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => :resource
  has_many :event_streams, :inverse_of => :physical_component, :dependent => :nullify
end
