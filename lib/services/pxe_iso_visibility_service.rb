class PxeIsoVisibilityService
  def determine_visibility(supports_iso, supports_pxe)
    field_names_to_edit = []
    field_names_to_hide = []

    if supports_pxe
      field_names_to_edit += %i[pxe_image_id pxe_server_id]
    else
      field_names_to_hide += %i[pxe_image_id pxe_server_id]
    end

    if supports_iso
      field_names_to_edit += [:iso_image_id]
    else
      field_names_to_hide += [:iso_image_id]
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end
end
