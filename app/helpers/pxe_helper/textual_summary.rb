module PxeHelper::TextualSummary
  def textual_group_basicinfo
    %i(uri_prefix uri access_url pxe_directory windows_images_directory
       customization_directory last_refreshed_on)
  end

  def textual_uri_prefix
    {:label => _("URI Prefix"), :value => "#{@ps.uri_prefix}"}
  end

  def textual_uri
    {:label => _("URI"), :value => "#{@ps.uri}"}
  end

  def textual_access_url
    {:label => _("Access URL"), :value => "#{@ps.access_url}"}
  end

  def textual_pxe_directory
    {:label => _("PXE Directory"), :value => "#{@ps.pxe_directory}"}
  end

  def textual_windows_images_directory
    {:label => _("Windows Images Directory"), :value => "#{@ps.windows_images_directory}"}
  end

  def textual_customization_directory
    {:label => _("Customization Directory"), :value => "#{@ps.customization_directory}"}
  end

  def textual_last_refreshed_on
    {:label => _("Last Refreshed On"), :value => "#{@ps.last_refresh_on}"}
  end

  def textual_group_pxe_image_menus
    %i(filename)
  end

  def textual_filename
    {:label => _("Filename"), :value => "#{@ps.pxe_menus[0].file_name}"}
  end

  def textual_pxe_img_basicinfo
    %i(pxe_img_name pxe_img_description pxe_img_type pxe_img_kernel pxe_img_win_boot_env)
  end

  def textual_pxe_img_name
    {:label => _("Name"), :value => "#{@img.name}"}
  end

  def textual_pxe_img_description
    {:label => _("Description"), :value => "#{@img.description}"}
  end

  def textual_pxe_img_type
    {:label => _("Type"), :value => @img.pxe_image_type ? "#{@img.pxe_image_type.name}" : ""}
  end

  def textual_pxe_img_kernel
    {:label => _("Kernel"), :value => "#{@img.kernel}"}
  end

  def textual_pxe_img_win_boot_env
    {:label => _("Windows Boot Environment"), :value => @img.default_for_windows ? "Yes" : ""}
  end

  def textual_win_img_basicinfo
    %i(win_img_name win_img_description win_img_type win_img_path win_img_index)
  end

  def textual_win_img_name
    {:label => _("Name"), :value => "#{@wimg.name}"}
  end

  def textual_win_img_description
    {:label => _("Description"), :value => "#{@wimg.description}"}
  end

  def textual_win_img_type
    {:label => _("Type"), :value => @wimg.pxe_image_type ? "#{@wimg.pxe_image_type.name}" : ""}
  end

  def textual_win_img_path
    {:label => _("Path"), :value => @wimg.path}
  end

  def textual_win_img_index
    {:label => _("Index"), :value => @wimg.index}
  end

  def textual_template_basicinfo
    %i(template_name template_description template_img_type template_type)
  end

  def textual_template_name
    {:label => _("Name"), :value => @ct.name}
  end

  def textual_template_description
    {:label => _("Description"), :value => @ct.description}
  end

  def textual_template_img_type
    {:label => _("Image Type"), :value => @ct.pxe_image_type ? "#{@ct.pxe_image_type.name}" : ""}
  end

  def textual_template_type
    {:label => _("Type"), :value => @ct.type.sub("CustomizationTemplate", "")}
  end

  def textual_sysimg_type_basicinfo
    %i(sysimg_type_name sysimg_type_provision_type)
  end

  def textual_sysimg_type_name
    {:label => _("Name"), :value => @pxe_image_type.name}
  end

  def textual_sysimg_type_provision_type
    {:label => _("Provision Type"), :value => @pxe_image_type.provision_type}
  end

  def textual_iso_datastore_basicinfo
    %i(iso_datastore_name iso_datastore_last_refresh_on)
  end

  def textual_iso_datastore_name
    {:label => ui_lookup(:table => "ext_management_system"), :value => @isd.name}
  end

  def textual_iso_datastore_last_refresh_on
    {:label => _("Last Refreshed On"), :value => @isd.last_refresh_on}
  end

  def textual_iso_img_info
    %i(iso_img_info_name iso_img_info_type)
  end

  def textual_iso_img_info_name
    {:label => _("Name"), :value => @img.name}
  end

  def textual_iso_img_info_type
    {:label => _("Type"), :value => @img.pxe_image_type ? @img.pxe_image_type.name : ""}
  end
end
