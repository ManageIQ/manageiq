class Switch < ApplicationRecord
  has_many :host_switches, :dependent => :destroy
  has_many :hosts, :through => :host_switches

  has_many :guest_devices
  has_many :lans, :dependent => :destroy

  include ReportableMixin
end
