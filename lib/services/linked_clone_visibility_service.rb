class LinkedCloneVisibilityService
  def determine_visibility(provision_type, linked_clone, snapshot_count)
    field_names_to_show = []
    field_names_to_edit = []
    field_names_to_hide = []

    if provision_type.to_s == 'vmware'
      if snapshot_count.positive?
        field_names_to_edit += [:linked_clone]
      else
        field_names_to_show += [:linked_clone]
      end

      if linked_clone == true
        field_names_to_edit += [:snapshot]
      else
        field_names_to_hide += [:snapshot]
      end
    else
      field_names_to_hide += %i[linked_clone snapshot]
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit, :show => field_names_to_show}
  end
end
