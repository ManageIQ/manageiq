require 'cim_profile_defs'
require 'ontap_logical_disk_mixin'

class OntapLogicalDisk < CimLogicalDisk
  virtual_column    :compressed_data,       :type => :integer
  virtual_column    :compression_saved_percentage,  :type => :float
  virtual_column    :dedup_percent_saved,     :type => :float
  virtual_column    :dedup_size_saved,        :type => :integer
  virtual_column    :dedup_size_shared,       :type => :integer
  virtual_column    :disk_count,          :type => :integer
  virtual_column    :files_total,         :type => :integer
  virtual_column    :files_used,          :type => :integer
  virtual_column    :is_compression_enabled,    :type => :boolean
  virtual_column    :is_inconsistent,       :type => :boolean
  virtual_column    :is_invalid,          :type => :boolean
  virtual_column    :is_unrecoverable,        :type => :boolean
  virtual_column    :size_available,        :type => :integer
  virtual_column    :size_total,          :type => :integer
  virtual_column    :size_used,           :type => :integer
  virtual_column    :snapshot_blocks_reserved,    :type => :integer
  virtual_column    :state,             :type => :string

  virtual_has_many  :ontap_file_shares,       :class_name => 'OntapFileShare'
  virtual_belongs_to  :ontap_storage_system,      :class_name => 'OntapStorageSystem'
  virtual_belongs_to  :ontap_flex_vol,        :class_name => 'OntapFlexVolExtent'

  include OntapLogicalDiskMixin

  LogicalDiskToFlexVol  = CimAssociations.ONTAP_LogicalDisk_TO_ONTAP_FlexVolExtent

  def ontap_flex_vol
    getAssociators(LogicalDiskToFlexVol).first
  end
end
