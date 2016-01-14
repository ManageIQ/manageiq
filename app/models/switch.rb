class Switch < ApplicationRecord
  belongs_to :host

  has_many :guest_devices
  has_many :lans, :dependent => :destroy

  include ReportableMixin
end
