module RepositoryHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    items = %w{vms miq_templates}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
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
    label = ui_lookup(:tables=>"miq_template")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'miq_templates')
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h     = {:label => label}
    tags  = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end
end
