class StorageFile < ApplicationRecord
  belongs_to :storage
  belongs_to :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id

  virtual_column :v_size_numeric, :type => :integer

  def self.is_snapshot_disk_file(file)
    return false unless file.ext_name == "vmdk"
    basename = File.basename(file.name, ".vmdk")
    i = basename.rindex('-')
    test_str = i.nil? ? basename : basename[i + 1..-1]
    test_str == "delta" || test_str =~ /^\d{6}$/
  end

  def self.split_file_types(files)
    ret = {:disk => [], :snapshot => [], :vm_ram => [], :vm_misc => [], :debris => []}

    files.each do |f|
      case f.ext_name
      when 'vmdk'
        if is_snapshot_disk_file(f)
          ret[:snapshot] << f
        else
          ret[:disk] << f
        end
      when 'vmsd', 'vmsn'
        ret[:snapshot] << f
      when 'nvram', 'vswp'
        ret[:vm_ram] << f
      when 'vmx', 'vmtx', 'vmxf', 'log', 'hlog'
        ret[:vm_misc] << f
      else
        if f.ext_name[0, 5] == "redo_"
          ret[:snapshot] << f
        else
          ret[:debris] << f
        end
      end
    end

    ret
  end

  def self.link_storage_files_to_vms(files, vm_ids_by_path, update = true)
    return if vm_ids_by_path.blank?

    files = [files] unless files.kind_of?(Array)
    files.each do |f|
      path = f.is_directory? ? f.name : File.dirname(f.name)
      vm_id = vm_ids_by_path[path]
      next if vm_id.nil?
      if update
        f.update_attribute(:vm_or_template_id, vm_id)
      else
        f.vm_or_template_id = vm_id
      end
    end
  end

  def is_file?
    rsc_type == "file"
  end

  def is_directory?
    rsc_type == "dir"
  end

  def v_size_numeric
    size.to_i
  end

  def self.display_name(number = 1)
    n_('Datastore File', 'Datastore Files', number)
  end
end
