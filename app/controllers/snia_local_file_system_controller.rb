class SniaLocalFileSystemController < CimInstanceController

  def index
    process_index
  end

  def button
    process_button
  end

  def show
    process_show(
      'cim_base_storage_extents' => :base_storage_extents,
      'ontap_file_share'         => :file_shares,
      'vms'                      => :vms,
      'hosts'                    => :hosts,
      'storages'                 => :storages
    )
  end

end
