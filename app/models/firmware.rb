class Firmware < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :physical_servers, :foreign_key => :ph_server_uuid, :class_name => "PhysicalServer"

end
