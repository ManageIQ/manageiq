module RepositoryHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    %i(vms templates)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_vms
    label = _("Discovered VMs")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_templates
    textual_link(@record.miq_templates,
                 :feature => "miq_template_show_list",
                 :as      => TemplateInfra,
                 :link    => url_for(:action => 'show', :id => @record, :display => 'miq_templates'))
  end
end
