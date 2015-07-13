class TreeBuilderAeClass  < TreeBuilder
  private

  def tree_init_options(tree_name)
    {:leaf => "datastore"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    objects = if MIQ_AE_COPY_ACTIONS.include?(@sb[:action])
                [MiqAeDomain.find_by_id(@sb[:domain_id])] # GIT support can't use where
              else
                filter_ae_objects(MiqAeDomain.all)
              end
    count_only_or_objects(options[:count_only], objects, [:priority]).reverse
  end

  def x_get_tree_class_kids(object, options)
    instances = count_only_or_objects(options[:count_only], object.ae_instances, [:display_name, :name])
    # show methods in automate explorer tree
    if options[:type] == :ae # FIXME: is this ever false?
      methods = count_only_or_objects(options[:count_only], object.ae_methods, [:display_name, :name])
      instances + methods
    else
      instances
    end
  end

  def x_get_tree_ns_kids(object, options)
    objects = filter_ae_objects(object.ae_namespaces)
    unless MIQ_AE_COPY_ACTIONS.include?(@sb[:action])
      ns_classes = filter_ae_objects(object.ae_classes)
      objects += ns_classes.flatten unless ns_classes.blank?
    end
    count_only_or_objects(options[:count_only], objects, [:display_name, :name])
  end

  def filter_ae_objects(objects)
    return objects unless @sb[:cached_waypoint_ids]
    klass_name = objects.first.class.name
    prefix = klass_name == "MiqAeDomain" ? "MiqAeNamespace" : klass_name
    objects.select { |obj| @sb[:cached_waypoint_ids].include?("#{prefix}::#{obj.id}") }
  end
end
