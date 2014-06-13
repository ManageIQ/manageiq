module RepositoryHelper::GraphicalSummary
  # TODO: Verify why there are onclick events with miqCheckForChanges(), but only on some links.

  #
  # Groups
  #

  def graphical_group_properties
    items = %w{vms miq_templates}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_vms
    label = "Discovered VMs"
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_miq_templates
    label = ui_lookup(:tables=>"miq_template")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'miq_templates'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
end
