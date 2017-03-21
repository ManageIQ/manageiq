class PhysicalServer < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  has_one :hardware, :dependent => :destroy

  has_one :host, :inverse_of => :physical_server

  def name_with_details
    details % {
      :name => name,
    }
  end
end
