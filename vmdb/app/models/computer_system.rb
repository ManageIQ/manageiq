class ComputerSystem < ActiveRecord::Base
  belongs_to :configured_system

  has_one :operating_system
  has_one :hardware
end
