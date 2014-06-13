class Lan < ActiveRecord::Base
  belongs_to :switch

  has_many :guest_devices
  has_many :vms_and_templates, :through => :guest_devices, :uniq => true
  has_many :vms,               :through => :guest_devices, :uniq => true
  has_many :miq_templates,     :through => :guest_devices, :uniq => true

  # TODO: Should this go through switch and not guest devices?
  has_many :hosts,             :through => :guest_devices, :uniq => true

  include ReportableMixin
end
