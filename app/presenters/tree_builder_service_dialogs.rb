class TreeBuilderServiceDialogs  < TreeBuilderAeCustomization
  private

  def tree_init_options(tree_name)
    {:leaf => "Dialog", :open_all => true }
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    objects = rbac_filtered_objects(Dialog.all).sort_by{|a| a.label.downcase}
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_generic_dialog_kids(object, options, chk_dialog_type = false)
    if chk_dialog_type == true && options[:type] == :dialogs
      objects = []
    else
      if options[:count_only]
        objects = object.dialog_resources
      else
        objects = object.ordered_dialog_resources.collect(&:resource).compact
      end
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_dialog_kids(object, options)
    x_get_tree_generic_dialog_kids(object, options, true)
  end

  def x_get_tree_dialog_tab_kids(object, options)
    x_get_tree_generic_dialog_kids(object, options)
  end

  def x_get_tree_dialog_group_kids(object, options)
    x_get_tree_generic_dialog_kids(object, options)
  end

end
