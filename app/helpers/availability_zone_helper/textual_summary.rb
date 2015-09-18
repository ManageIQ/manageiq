module AvailabilityZoneHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_relationships
    %i(ems_cloud instances)
  end

  def textual_group_tags
    %i(tags)
  end

  #
  # Items
  #

  def textual_ems_cloud
    textual_link(@record.ext_management_system)
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
end
