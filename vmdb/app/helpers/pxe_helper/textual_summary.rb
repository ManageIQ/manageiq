module PxeHelper::TextualSummary
  def textual_group_basicinfo
    items = %w(uri_prefix uri access_url pxe_directory windows_images_directory
               customization_directory last_refreshed_on)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_uri_prefix
    {:label => "URI Prefix", :value => "#{@ps.uri_prefix}"}
  end

  def textual_uri
    {:label => "URI", :value => "#{@ps.uri}"}
  end

  def textual_access_url
    {:label => "Access URL", :value => "#{@ps.access_url}"}
  end

  def textual_pxe_directory
    {:label => "PXE Directory", :value => "#{@ps.pxe_directory}"}
  end

  def textual_windows_images_directory
    {:label => "Windows Images Directory", :value => "#{@ps.windows_images_directory}"}
  end

  def textual_customization_directory
    {:label => "Customization Directory", :value => "#{@ps.customization_directory}"}
  end

  def textual_last_refreshed_on
    {:label => "Last Refreshed On", :value => "#{@ps.last_refresh_on}"}
  end

  def textual_group_pxe_image_menus
    items = %w(filename)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_filename
    {:label => "Filename", :value => "#{@ps.pxe_menus[0].file_name}"}
  end

  def textual_pxe_img_basicinfo
    items = %w(name description type kernel win_boot_env)
    items.collect { |m| send("textual_pxe_img_#{m}") }.flatten.compact
  end

  def textual_pxe_img_name
    {:label => "Name", :value => "#{@img.name}"}
  end

  def textual_pxe_img_description
    {:label => "Description", :value => "#{@img.description}"}
  end

  def textual_pxe_img_type
    {:label => "Type", :value => @img.pxe_image_type ? "#{@img.pxe_image_type.name}" : ""}
  end

  def textual_pxe_img_kernel
    {:label => "Kernel", :value => "#{@img.kernel}"}
  end

  def textual_pxe_img_win_boot_env
    {:label => "Windows Boot Environment", :value => @img.default_for_windows ? "Yes" : ""}
  end

  def textual_win_img_basicinfo
    items = %w(name description type path index)
    items.collect { |m| send("textual_win_img_#{m}") }.flatten.compact
  end

  def textual_win_img_name
    {:label => "Name", :value => "#{@wimg.name}"}
  end

  def textual_win_img_description
    {:label => "Description", :value => "#{@wimg.description}"}
  end

  def textual_win_img_type
    {:label => "Type", :value => @wimg.pxe_image_type ? "#{@wimg.pxe_image_type.name}" : ""}
  end

  def textual_win_img_path
    {:label => "Path", :value => @wimg.path}
  end

  def textual_win_img_index
    {:label => "Index", :value => @wimg.index}
  end
end
