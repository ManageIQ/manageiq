class TreeBuilderOpsSettings < TreeBuilderOps

  private

  def tree_init_options(tree_name)
    {
      :open_all   => true,
      :leaf       => "Settings"
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix      => "settings_",
        :autoload       => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    objects = [
        {:id => "sis", :text => "Analysis Profiles", :image => "scan_item_set", :tip => "Analysis Profiles"},
        {:id => "z", :text => "Zones", :image => "zone", :tip => "Zones"}
    ]
    objects.push({:id => "l", :text => "LDAP", :image => "ldap", :tip => "LDAP"}) if get_vmdb_config[:product][:new_ldap]
    objects.push({:id => "msc", :text => "Schedules", :image => "miq_schedule", :tip => "Schedules"})
    objects
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    case object[:id]
    when "l"
      count_only_or_objects(options[:count_only], LdapRegion.all, "name.to_s")
    when "msc"
      objects = []
      MiqSchedule.all(:conditions=>"prod_default != 'system' or prod_default is null").sort{
          |a,b| a.name.downcase <=> b.name.downcase}.each do |z|
        objects.push(z) if z.adhoc.nil? && (z.towhat != "DatabaseBackup" || (z.towhat == "DatabaseBackup" && DatabaseBackup.backup_supported?))
      end
      count_only_or_objects(options[:count_only], objects, nil)
    when "sis"
      count_only_or_objects(options[:count_only], ScanItemSet.all, "name")
    when "z"
      region = MiqRegion.my_region
      count_only_or_objects(options[:count_only], region.zones, "name")
    end
  end
end
