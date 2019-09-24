class Switch < ApplicationRecord
  include NewWithTypeStiMixin
  include CustomActionsMixin

  belongs_to :host, :inverse_of => :host_virtual_switches

  has_many :host_switches, :dependent => :destroy
  has_many :hosts, :through => :host_switches

  has_many :guest_devices
  has_many :lans, :dependent => :destroy
  has_many :subnets, :through => :lans

  scope :shareable, ->     { where(:shared => true) }
  scope :with_id,   ->(id) { where(:id => id) }

  acts_as_miq_taggable
end
