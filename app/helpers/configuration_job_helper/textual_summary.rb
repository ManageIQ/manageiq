module ConfigurationJobHelper::TextualSummary
  include TextualMixins::TextualDescription
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name description type status status_reason)
  end

  def textual_group_relationships
    %i(provider service security_groups parameters outputs resources)
  end

  #
  # Items
  #
  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_status
    @record.status
  end

  def textual_status_reason
    @record.status_reason
  end

  def textual_service
    h = {:label => _("Service"), :image => "service"}
    service = @record.service
    if service.nil?
      h[:value] = _("None")
    else
      h[:value] = service.name
      h[:title] = _("Show this Service")
      h[:link]  = url_for(:controller => 'service', :action => 'show', :id => to_cid(service.id))
    end
    h
  end

  def textual_provider
    h = {:label => _("Provider"), :image => "vendor-ansible_tower_configuration"}
    provider = @record.ext_management_system
    if provider.nil?
      h[:value] = _("None")
    else
      h[:value] = provider.name
      h[:title] = _("Show this Parent Provider")
      h[:link]  = url_for(:controller => 'provider_foreman', :action => 'explorer', :id => "at-#{to_cid(provider.id)}")
    end
    h
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_parameters
    num   = @record.number_of(:parameters)
    h     = {:label => _("Parameters"), :image => "parameter", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'parameters', :id => @record)
      h[:title] = _("Show all parameters")
    end
    h
  end

  def textual_outputs
    num   = @record.number_of(:outputs)
    h     = {:label => _("Outputs"), :image => "output", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'outputs', :id => @record)
      h[:title] = _("Show all outputs")
    end
    h
  end

  def textual_resources
    num   = @record.number_of(:resources)
    h     = {:label => _("Resources"), :image => "resource", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'resources', :id => @record)
      h[:title] = _("Show all resources")
    end
    h
  end
end
