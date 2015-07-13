class OntapStorageVolumeController < CimInstanceController

  def index
    process_index
  end

  def button
    process_button
  end

  def show
    process_show(
      'cim_base_storage_extents' => :base_storage_extents,
      'vms'                      => :vms,
      'hosts'                    => :hosts,
      'storages'                 => :storages
    )
  end

  def show_list
    process_show_list
  end

end
