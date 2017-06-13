class GuestDevice < ApplicationRecord
  belongs_to :hardware
  belongs_to :guest_device, :foreign_key => "guest_device_id", :class_name => "GuestDevice"

  has_one :vm_or_template, :through => :hardware
  has_one :vm,             :through => :hardware
  has_one :miq_template,   :through => :hardware
  has_one :host,           :through => :hardware

  belongs_to :switch    # pNICs link to one switch
  belongs_to :lan       # vNICs link to one lan

  has_one :network, :foreign_key => "device_id", :dependent => :destroy, :inverse_of => :guest_device
  has_many :miq_scsi_targets, :dependent => :destroy

  has_many :firmwares, :dependent => :destroy
  has_many :guest_devices, :dependent => :destroy, :foreign_key => "guest_device_id",  :class_name => "GuestDevice"
end
