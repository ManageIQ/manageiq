class AutoPlacementVisibilityService
  def determine_visibility(auto_placement_enabled)
    field_names_to_hide = []
    field_names_to_edit = []

    auto_placement_values = %i[
      placement_host_name
      placement_ds_name
      host_filter
      ds_filter
      cluster_filter
      placement_cluster_name
      rp_filter
      placement_rp_name
      placement_dc_name
    ]

    if auto_placement_enabled
      field_names_to_hide += auto_placement_values
    else
      field_names_to_edit += auto_placement_values
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end
end
