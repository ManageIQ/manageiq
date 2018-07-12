class Switch < ApplicationRecord
  include NewWithTypeStiMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :distributed_virtual_switches,
             :class_name => "ManageIQ::Providers::InfraManager"

  has_many :host_switches, :dependent => :destroy
  has_many :hosts, :through => :host_switches

  has_many :guest_devices
  has_many :lans, :dependent => :destroy
  has_many :subnets, :through => :lans

  scope :shareable, ->     { where(:shared => true) }
  scope :with_id,   ->(id) { where(:id => id) }

  acts_as_miq_taggable
end
