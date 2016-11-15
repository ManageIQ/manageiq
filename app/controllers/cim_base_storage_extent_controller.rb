class CimBaseStorageExtentController < CimInstanceController
  def button
    process_button
  end

  def show
    process_show(
      'ontap_logical_disks'     => :logical_disks,
      'ontap_storage_volumes'   => :storage_volumes,
      'ontap_file_shares'       => :file_shares,
      'snia_local_file_systems' => :file_systems,
      'vms'                     => :vms,
      'hosts'                   => :hosts,
      'storages'                => :storages
    )
  end
end
