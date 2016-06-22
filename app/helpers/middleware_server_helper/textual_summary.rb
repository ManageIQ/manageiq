module MiddlewareServerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name hostname feed bind_addr product version)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    %i(ems middleware_deployments middleware_datasources lives_on)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_hostname
    @record.hostname
  end

  def textual_feed
    @record.feed
  end

  def textual_bind_addr
    {:label => _('Bind Address'),
     :value => @record.properties['Bound Address']}
  end

  def textual_product
    @record.product
  end

  def textual_version
    @record.properties['Version']
  end

  def textual_lives_on
    lives_on_ems = @record.try(:lives_on).try(:ext_management_system)
    return nil if lives_on_ems.nil?
    lives_on_entity_name = _("Virtual Machine")
     {
         :label      => "Underlying #{lives_on_entity_name}",
         :image      => "vendor-#{lives_on_ems.image_name}",
         :value      => "#{@record.lives_on.name}",
         :link       => url_for(
           :action     => 'show',
           :controller => 'vm_or_template',
           :id         => @record.lives_on.id
          )
     }
  end
end
