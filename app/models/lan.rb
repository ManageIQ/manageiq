class Lan < ApplicationRecord
  belongs_to :switch

  has_many :subnets, :dependent => :destroy
  has_many :guest_devices
  has_many :vms_and_templates, -> { distinct }, :through => :guest_devices
  has_many :vms,               -> { distinct }, :through => :guest_devices
  has_many :miq_templates,     -> { distinct }, :through => :guest_devices

  has_many :lans, :foreign_key => :parent_id
  belongs_to :parent, :class_name => "::Lan"

  # TODO: Should this go through switch and not guest devices?
  has_many :hosts,             :through => :guest_devices

  acts_as_miq_taggable
end
