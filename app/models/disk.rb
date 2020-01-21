class Disk < ApplicationRecord
  belongs_to :hardware
  belongs_to :storage
  belongs_to :storage_profile
  belongs_to :backing, :polymorphic => true
  has_many :partitions
  virtual_column :allocated_space,             :type => :integer, :uses => :partitions
  virtual_column :allocated_space_percent,     :type => :float,   :uses => :allocated_space
  virtual_column :unallocated_space,           :type => :integer, :uses => :allocated_space
  virtual_column :unallocated_space_percent,   :type => :float,   :uses => :unallocated_space
  virtual_column :used_percent_of_provisioned, :type => :float
  virtual_column :partitions_aligned,          :type => :string,  :uses => {:partitions => :aligned}
  virtual_column :used_disk_storage, :type => :integer, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::NamedFunction.new('COALESCE', [t[:size_on_disk], t[:size], 0]))
  end)

  def self.find_hard_disks
    where("device_type != 'floppy' AND device_type NOT LIKE '%cdrom%'").to_a
  end

  def self.find_floppies
    where("device_type = 'floppy'").to_a
  end

  def self.find_cdroms
    where("device_type LIKE '%cdrom%'").to_a
  end

  def allocated_space
    return nil if size.nil?
    partitions.inject(0) { |t, p| t + p.size }
  end

  def allocated_space_percent
    return nil if size.nil? || size == 0
    Float(allocated_space) / size * 100
  end

  def unallocated_space
    return nil if size.nil?
    size - allocated_space
  end

  def unallocated_space_percent
    return nil if size.nil? || size == 0
    Float(unallocated_space) / size * 100
  end

  def volumes
    partitions.collect(&:volumes).flatten.uniq
  end

  def used_percent_of_provisioned
    size.to_i == 0 ? 0.0 : (size_on_disk.to_f / size.to_f * 1000.0).round / 10.0
  end

  def rdm_disk?
    disk_type && disk_type.starts_with?("rdm")
  end

  def partitions_aligned
    return "Not Applicable" if self.rdm_disk?
    plist = partitions
    return "Unknown" if plist.empty?
    return "True"    if plist.all?(&:aligned?)
    return "False"   if plist.any? { |p| p.aligned? == false }
    "Unknown"
  end

  def used_disk_storage
    size_on_disk || size || 0
  end
end
