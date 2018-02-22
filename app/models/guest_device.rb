class GuestDevice < ApplicationRecord
  belongs_to :hardware
  belongs_to :parent_device, :class_name => "GuestDevice"

  has_one :vm_or_template, :through => :hardware
  has_one :vm,             :through => :hardware
  has_one :miq_template,   :through => :hardware
  has_one :host,           :through => :hardware

  belongs_to :switch    # pNICs link to one switch
  belongs_to :lan       # vNICs link to one lan

  has_one :network, :foreign_key => "device_id", :dependent => :destroy, :inverse_of => :guest_device
  has_many :miq_scsi_targets, :dependent => :destroy

  has_many :firmwares, :dependent => :destroy
  has_many :child_devices, :class_name => "GuestDevice", :foreign_key => :parent_device_id, :dependent => :destroy
end
