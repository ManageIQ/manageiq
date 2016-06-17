class CustomizeFieldsVisibilityService
  def determine_visibility(platform, supports_customization_template, customize_fields_list)
    field_names_to_show = []
    field_names_to_hide = []

    if supports_customization_template
      field_names_to_show += [
        :addr_mode,
        :customization_template_id,
        :customization_template_script,
        :dns_servers,
        :dns_suffixes,
        :gateway,
        :hostname,
        :ip_addr,
        :root_password,
        :subnet_mask
      ]
    else
      exclude_list = [
        :sysprep_spec_override,
        :sysprep_custom_spec,
        :sysprep_enabled,
        :sysprep_upload_file,
        :sysprep_upload_text,
        :linux_host_name,
        :sysprep_computer_name,
        :ip_addr,
        :subnet_mask,
        :gateway,
        :dns_servers,
        :dns_suffixes
      ]

      customize_fields_list.each do |field_name|
        next if exclude_list.include?(field_name)

        if platform == "linux"
          if field_name == :linux_domain_name
            field_names_to_show << field_name
          else
            field_names_to_hide << field_name
          end
        end
      end
    end

    {:hide => field_names_to_hide, :show => field_names_to_show}
  end
end
