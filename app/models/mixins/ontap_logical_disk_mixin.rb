module OntapLogicalDiskMixin

  def ontap_storage_system
    storage_system
  end

  def ontap_file_shares
    file_shares
  end

  def compressed_data
    check_int(self.type_spec_obj.compression_info.compressed_data)
  end
  def compression_saved_percentage
    check_float(self.type_spec_obj.compression_info.compression_saved_percentage)
  end
  def dedup_percent_saved
    check_float(sis_info('dedup-percent-saved'))
  end
  def dedup_size_saved
    check_int(sis_info('dedup-size-saved'))
  end
  def dedup_size_shared
    check_int(sis_info('dedup-size-shared'))
  end
  def disk_count
    check_int(self.type_spec_obj.disk_count)
  end
  def files_total
    check_int(self.type_spec_obj.files_total)
  end
  def files_used
    check_int(self.type_spec_obj.files_used)
  end
  def is_compression_enabled
    check_bool(self.type_spec_obj.compression_info.is_compression_enabled)
  end
  def is_inconsistent
    check_bool(self.type_spec_obj.is_inconsistent)
  end
  def is_invalid
    check_bool(self.type_spec_obj.is_invalid)
  end
  def is_unrecoverable
    check_bool(self.type_spec_obj.is_unrecoverable)
  end
  def size_available
    check_int(self.type_spec_obj.size_available)
  end
  def size_total
    check_int(self.type_spec_obj.size_total)
  end
  def size_used
    check_int(self.type_spec_obj.size_used)
  end
  def snapshot_blocks_reserved
    check_int(self.type_spec_obj.snapshot_blocks_reserved)
  end
  def state
    self.type_spec_obj.state
  end

  def check_int(val)
    return nil if val.nil?
    return val.to_i
  end
  def check_float(val)
    return nil if val.nil?
    return val.to_f
  end
  def check_bool(val)
    return false if val.nil?
    return val.casecmp("true") == 0
  end

  def sis_info(key)
    return nil if self.type_spec_obj.sis.nil? || self.type_spec_obj.sis.sis_info.nil?
    return self.type_spec_obj.sis.sis_info[key]
  end

end
