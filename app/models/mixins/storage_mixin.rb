module StorageMixin
  extend ActiveSupport::Concern
  STORAGE_FILE_TYPES = [:vm_ram, :snapshot, :disk, :debris, :vm_misc]

  # Used to extend classes that utilize the StorageFiles class (Storage and Vm)
  included do
    STORAGE_FILE_TYPES.each do |m|
      virtual_column   "#{m}_size",  :type => :integer,            :uses => :"#{m}_files"
      virtual_has_many :"#{m}_files", :class_name => "StorageFile", :uses => :storage_files_files
    end
  end

  STORAGE_FILE_TYPES.each do |m|
    send(:define_method, "#{m}_size")  { add_files_sizes("#{m}_files") }
    send(:define_method, "#{m}_files") { storage_files_by_type[m] }
  end

  def storage_files_by_type
    return @storage_files_by_type unless @storage_files_by_type.nil?
    @storage_files_by_type = StorageFile.split_file_types(storage_files_files)
  end

  def add_files_sizes(file_method, *args)
    send(file_method, *args).inject(0) { |ts, f| ts + f.size.to_i }
  end
end
