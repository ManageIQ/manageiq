class Disk < ActiveRecord::Base
  belongs_to :hardware
  belongs_to :storage
  belongs_to :backing, :polymorphic => true
  has_many :partitions
  has_one :miq_cim_instance, :as => :vmdb_obj, :dependent => :destroy

  include ReportableMixin

  virtual_column :allocated_space,             :type => :integer, :uses => :partitions
  virtual_column :allocated_space_percent,     :type => :float,   :uses => :allocated_space
  virtual_column :unallocated_space,           :type => :integer, :uses => :allocated_space
  virtual_column :unallocated_space_percent,   :type => :float,   :uses => :unallocated_space
  virtual_column :used_percent_of_provisioned, :type => :float
  virtual_column :partitions_aligned,          :type => :string,  :uses => {:partitions => :aligned}

  virtual_has_many  :base_storage_extents, :class_name => "CimStorageExtent"
  virtual_has_many  :storage_systems,      :class_name => "CimComputerSystem"

  def self.find_hard_disks
    self.find(:all, :conditions => "device_type != 'floppy' AND device_type NOT LIKE '%cdrom%'")
  end

  def self.find_floppies
    self.find(:all, :conditions => "device_type = 'floppy'")
  end

  def self.find_cdroms
    self.find(:all, :conditions => "device_type LIKE '%cdrom%'")
  end

  def allocated_space
    return nil if self.size.nil?
    return self.partitions.inject(0) { |t, p| t + p.size }
  end

  def allocated_space_percent
    return nil if self.size.nil? || self.size == 0
    Float(self.allocated_space) / self.size * 100
  end

  def unallocated_space
    return nil if self.size.nil?
    return self.size - self.allocated_space
  end

  def unallocated_space_percent
    return nil if self.size.nil? || self.size == 0
    Float(self.unallocated_space) / self.size * 100
  end

  def volumes
    self.partitions.collect { |p| p.volumes }.flatten.uniq
  end

  def used_percent_of_provisioned
    return self.size.to_i == 0 ? 0.0 : (self.size_on_disk.to_f / self.size.to_f * 1000.0).round / 10.0
  end

  def rdm_disk?
    self.disk_type && self.disk_type.starts_with?("rdm")
  end

  def partitions_aligned
    return "Not Applicable" if self.rdm_disk?
    plist = self.partitions
    return "Unknown" if plist.empty?
    return "True"    if plist.all? {|p| p.aligned?}
    return "False"   if plist.any? {|p| p.aligned? == false}
    return "Unknown"
  end

  def base_storage_extents
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.base_storage_extents
  end

  def storage_systems
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.storage_systems
  end

end
