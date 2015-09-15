module RepositoryHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    %i(vms miq_templates)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_vms
    label = "Discovered VMs"
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_miq_templates
    textual_link(@record.miq_templates)
  end
end
