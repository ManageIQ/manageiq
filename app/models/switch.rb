class Switch < ApplicationRecord
  has_and_belongs_to_many :hosts

  has_many :guest_devices
  has_many :lans, :dependent => :destroy

  include ReportableMixin
end
