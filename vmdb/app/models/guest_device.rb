class GuestDevice < ActiveRecord::Base
  belongs_to :hardware
  has_one :vm_or_template, :through => :hardware
  has_one :vm,             :through => :hardware
  has_one :miq_template,   :through => :hardware
  has_one :host,           :through => :hardware

  belongs_to :switch    # pNICs link to one switch
  belongs_to :lan       # vNICs link to one lan

  has_one :network, :foreign_key => "device_id", :dependent => :destroy
  has_many :miq_scsi_targets, :dependent => :destroy

  include ReportableMixin
end
