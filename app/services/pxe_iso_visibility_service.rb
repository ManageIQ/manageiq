class PxeIsoVisibilityService
  def determine_visibility(supports_iso, supports_pxe)
    field_names_to_show = []
    field_names_to_hide = []

    if supports_pxe
      field_names_to_show += [:pxe_image_id, :pxe_server_id]
    else
      field_names_to_hide += [:pxe_image_id, :pxe_server_id]
    end

    if supports_iso
      field_names_to_show += [:iso_image_id]
    else
      field_names_to_hide += [:iso_image_id]
    end

    {:hide => field_names_to_hide, :show => field_names_to_show}
  end
end
