class Lan < ActiveRecord::Base
  belongs_to :switch

  has_many :guest_devices
  has_many :vms_and_templates, -> { distinct }, :through => :guest_devices
  has_many :vms,               -> { distinct }, :through => :guest_devices
  has_many :miq_templates,     -> { distinct }, :through => :guest_devices

  # TODO: Should this go through switch and not guest devices?
  has_many :hosts,             :through => :guest_devices

  include ReportableMixin
end
