module MiddlewareDatasourceHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name nativeid driver_name jndi_name connection_url enabled)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    %i(ems middleware_server)
  end

  def textual_group_smart_management
    %i(tags)
  end

  def textual_name
    @record.name
  end

  def textual_nativeid
    @record.nativeid
  end

  def textual_driver_name
    {:label => _('Driver Name'),
     :value => @record.properties['Driver Name']}
  end

  def textual_jndi_name
    {:label => _('JNDI Name'),
     :value => @record.properties['JNDI Name']}
  end

  def textual_connection_url
    {:label => _('Connection URL'),
     :value => @record.properties['Connection URL']}
  end

  def textual_enabled
    {:label => _('Enabled'),
     :value => @record.properties['Enabled']}
  end
end
