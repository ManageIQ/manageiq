class CustomizeFieldsVisibilityService
  def determine_visibility(platform, supports_customization_template, customize_fields_list)
    field_names_to_edit = []
    field_names_to_hide = []

    if supports_customization_template
      field_names_to_edit += %i[
        addr_mode
        customization_template_id
        customization_template_script
        dns_servers
        dns_suffixes
        gateway
        hostname
        ip_addr
        root_password
        subnet_mask
        sysprep_admin_password
        sysprep_computer_name
        sysprep_domain_name
        sysprep_domain_password
        sysprep_locale_input
        sysprep_locale_system
        sysprep_locale_ui
        sysprep_locale_user
        sysprep_machine_object_ou
        sysprep_product_key
        sysprep_timezone
        sysprep_domain_admin
      ]
    else
      exclude_list = %i[
        sysprep_spec_override
        sysprep_custom_spec
        sysprep_enabled
        sysprep_upload_file
        sysprep_upload_text
        linux_host_name
        ip_addr
        subnet_mask
        gateway
        dns_servers
        dns_suffixes
      ]

      customize_fields_list.each do |field_name|
        next if exclude_list.include?(field_name)
        next unless platform == "linux"

        if field_name == :linux_domain_name
          field_names_to_edit << field_name
        else
          field_names_to_hide << field_name
        end
      end
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end
end
