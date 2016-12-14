module TextualMixins::TextualOsInfo
  def textual_osinfo
    h = {:label => _("Operating System")}
    product_name = @record.product_name
    if product_name.blank?
      os_image_name = @record.os_image_name
      if os_image_name.blank?
        h[:value] = _("Unknown")
      else
        h[:image] = "100/os-#{os_image_name.downcase}.png"
        h[:value] = os_image_name
      end
    else
      h[:image] = "100/os-#{@record.os_image_name.downcase}.png"
      h[:value] = product_name
      h[:title] = _("Show OS container information")
      h[:explorer] = true
      h[:link] = url_for(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end
end
