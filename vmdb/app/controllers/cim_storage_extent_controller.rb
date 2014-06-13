class CimStorageExtentController < CimInstanceController

  def index
    process_index
  end

  def button
    process_button
  end

  def show
    process_show(
      'ontap_logical_disks'       => :logical_disks,
      'ontap_storage_volumes'     => :storage_volumes,
      'snia_local_file_systems' => :local_file_systems,
      'vms'                     => :vms,
      'hosts'                   => :hosts,
      'storages'                => :storages
    )
  end

  def show_list
    process_show_list
  end

end
