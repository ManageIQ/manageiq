module HostAggregateHelper::TextualSummary
  include TextualMixins::TextualEmsCloud
  include TextualMixins::TextualGroupTags
  #
  # Groups
  #

  def textual_group_relationships
    %i(ems_cloud instances hosts)
  end

  #
  # Items
  #

  def textual_hosts
    label = ui_lookup(:tables => "host")
    num   = @record.number_of(:hosts)
    h     = {:label => label, :icon => "pficon pficon-screen", :value => num}
    if num > 0 && role_allows?(:feature => "host_show_list")
      h[:link]  = url_for(:action => 'show', :id => @host_aggregate, :display => 'hosts')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @host_aggregate, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end
end
