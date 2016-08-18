module InfraNetworkingHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(switch_type)
  end

  def textual_group_relationships
    %i(hosts)
  end

  def textual_group_smart_management
    %i(tags)
  end

    #
  # Items
  #

  def textual_switch_type
    {:label => _("%{switch} Type") % {:switch=> ui_lookup(:table => "switches")}, :value => @record.shared}
  end


  def textual_hosts
    num = @record.number_of(:hosts)
    h = {:label => title_for_hosts, :image => "host", :value => num}
    if num > 0 && role_allows?(:feature => "host_show_list")
      h[:title] = _("Show all %{title}") % {:title => title_for_hosts}
      h[:link]  = url_for(:controller => 'infra_networking', :action => 'show', :id => @record, :display => 'hosts')
    end
    h
    end
end

