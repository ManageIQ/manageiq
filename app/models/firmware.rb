class Firmware < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :physical_servers, :foreign_key => :ph_server_id, :class_name => "PhysicalServer"
end
