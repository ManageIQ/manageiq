class TreeBuilderOpsSettings < TreeBuilderOps
  private

  def tree_init_options(_tree_name)
    {
      :open_all => true,
      :leaf     => "Settings"
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    region = MiqRegion.my_region
    title =  _("%{product} Region: %{region_description} [%{region}]") % {:region_description => region.description,
                                                                          :region             => region.region,
                                                                          :product            => I18n.t('product.name')}
    [title, title, '100/miq_region.png']
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_count_only, _options)
    objects = [
      {:id => "sis", :text => _("Analysis Profiles"), :image => "scan_item_set", :tip => _("Analysis Profiles")},
      {:id => "z", :text => _("Zones"), :image => "zone", :tip => _("Zones")}
    ]
    if Settings.product.new_ldap
      objects.push(:id => "l", :text => _("LDAP"), :image => "ldap", :tip => _("LDAP"))
    end
    objects.push(:id => "msc", :text => _("Schedules"), :image => "miq_schedule", :tip => _("Schedules"))
    objects
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, count_only, _options)
    case object[:id]
    when "l"
      count_only_or_objects(count_only, LdapRegion.all, "name")
    when "msc"
      objects = MiqSchedule.where("(prod_default != 'system' or prod_default is null) AND adhoc is null")
      count_only_or_objects(count_only, objects, "name")
    when "sis"
      count_only_or_objects(count_only, ScanItemSet.all, "name")
    when "z"
      region = MiqRegion.my_region
      count_only_or_objects(count_only, region.zones, "name")
    end
  end
end
