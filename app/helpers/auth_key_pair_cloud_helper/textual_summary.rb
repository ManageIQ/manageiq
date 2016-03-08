module AuthKeyPairCloudHelper::TextualSummary
  #
  # Groups
  #
  def textual_group_relationships
    %i(vms)
  end

  def textual_group_tags
    %i(tags)
  end

  def textual_group_properties
    %i(name type fingerprint)
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_type
    @record.type
  end

  def textual_fingerprint
    @record.fingerprint
  end

  def textual_vms
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end
end
