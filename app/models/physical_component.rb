#
# A hub to centralize the Physical Components relationships.
#   and a common way to access the Physical Components.
#
# Physical Components:
#   - Physical Chassis;
#   - Physical Rack.
#   - Physical Server;
#   - Physical Switch;
#
class PhysicalComponent < ApplicationRecord
  belongs_to :component, :polymorphic => true
end
