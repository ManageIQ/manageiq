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
  def textual_hosts
    num = @record.number_of(:hosts)
    h = {:label => title_for_hosts, :icon => "pficon pficon-screen", :value => num}
    if num > 0 && role_allows?(:feature => "host_show_list")
      h = {:label => title_for_hosts, :icon => "pficon pficon-screen", :value => num}
      h[:explorer] = true
      h[:link] = url_for(:action => 'hosts', :id => @record, :db => 'switch')
    end
    h
  end
end
