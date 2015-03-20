class TreeBuilderAeClass  < TreeBuilder
  attr_reader :tree_nodes

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
                filter_ae_objects(MiqAeDomain.all, @sb[:fqname_array])
              end
    count_only_or_objects(options[:count_only], objects, [:priority]).reverse
  end

  def x_get_tree_class_kids(object, options)
    instances = count_only_or_objects(options[:count_only], object.ae_instances, [:display_name, :name])
    # show methods in automate explorer tree
    if x_active_tree == :ae_tree
      methods = count_only_or_objects(options[:count_only], object.ae_methods, [:display_name, :name])
      instances + methods
    else
      instances
    end
  end

  def x_get_tree_ns_kids(object, options)
    objects = filter_ae_objects(object.ae_namespaces, @sb[:fqname_array])
    unless MIQ_AE_COPY_ACTIONS.include?(@sb[:action])
      ns_classes = filter_ae_objects(object.ae_classes, @sb[:fqname_array])
      objects += ns_classes.flatten unless ns_classes.blank?
    end
    count_only_or_objects(options[:count_only], objects, [:display_name, :name])
  end

  def filter_ae_objects(objects, fqname_array)
    return objects unless fqname_array
    objects.select { |obj| fqname_array.include?(obj.fqname) }
  end
end
