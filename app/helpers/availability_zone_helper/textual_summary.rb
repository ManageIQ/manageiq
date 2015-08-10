module AvailabilityZoneHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_relationships
    items = %w{ems_cloud instances}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_ems_cloud
    textual_link(@record.ext_management_system, :as => EmsCloud)
  end

  def textual_instances
    label = ui_lookup(:tables=>"vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @availability_zone, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.blank?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end



end
