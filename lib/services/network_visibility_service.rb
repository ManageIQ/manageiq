class NetworkVisibilityService
  def determine_visibility(sysprep_enabled, supports_pxe, supports_iso, addr_mode)
    field_names_to_hide = []
    field_names_to_edit = []

    if show_dns_settings?(sysprep_enabled, supports_pxe, supports_iso)
      field_names_to_edit += %i[addr_mode dns_suffixes dns_servers]

      if show_ip_settings?(addr_mode, supports_pxe, supports_iso)
        field_names_to_edit += %i[ip_addr subnet_mask gateway]
      else
        field_names_to_hide += %i[ip_addr subnet_mask gateway]
      end
    else
      field_names_to_hide += %i[addr_mode ip_addr subnet_mask gateway dns_servers dns_suffixes]
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end

  private

  def show_dns_settings?(sysprep_enabled, supports_pxe, supports_iso)
    sysprep_enabled.in?(%w[fields file]) || supports_pxe || supports_iso
  end

  def show_ip_settings?(addr_mode, supports_pxe, supports_iso)
    addr_mode == "static" || supports_pxe || supports_iso
  end
end
