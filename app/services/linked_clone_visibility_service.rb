class LinkedCloneVisibilityService
  def determine_visibility(provision_type, linked_clone)
    field_names_to_show = []
    field_names_to_hide = []

    if provision_type.to_s == 'vmware'
      field_names_to_show += [:linked_clone]
      if linked_clone == true
        field_names_to_show += [:snapshot]
      else
        field_names_to_hide += [:snapshot]
      end
    else
      field_names_to_hide += [:linked_clone, :snapshot]
    end

    {:hide => field_names_to_hide, :show => field_names_to_show}
  end
end
