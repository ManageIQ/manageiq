class PhysicalRack < ApplicationRecord
  include SupportsFeatureMixin
  include EmsRefreshMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_racks,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  has_many :physical_chassis, :dependent => :nullify, :inverse_of => :physical_rack
  has_many :physical_servers, :dependent => :nullify, :inverse_of => :physical_rack
  has_many :physical_storages, :dependent => :nullify, :inverse_of => :physical_rack

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end
end
