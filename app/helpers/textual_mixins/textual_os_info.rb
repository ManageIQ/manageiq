module TextualMixins::TextualOsInfo
  def textual_osinfo
    h = {:label => _("Operating System")}
    os = @record.operating_system.nil? ? nil : @record.operating_system.product_name
    if os.blank?
      h[:value] = _("Unknown")
    else
      h[:image] = "os-#{@record.os_image_name.downcase}"
      h[:value] = os
      h[:title] = _("Show OS container information")
      h[:explorer] = true
      h[:link] = url_for(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end
end
