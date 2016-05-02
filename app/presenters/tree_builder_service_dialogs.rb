class TreeBuilderServiceDialogs < TreeBuilderAeCustomization
  has_kids_for DialogGroup, [:x_get_tree_dialog_group_kids, :type]
  has_kids_for DialogTab, [:x_get_tree_dialog_tab_kids, :type]

  private

  def tree_init_options(_tree_name)
    {:leaf => "Dialog", :open_all => true}
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = rbac_filtered_objects(Dialog.all).sort_by { |a| a.label.downcase }
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_generic_dialog_kids(object, count_only, type, chk_dialog_type = false)
    objects =
      if chk_dialog_type == true && type == :dialogs
        []
      elsif count_only
        object.dialog_resources
      else
        object.ordered_dialog_resources.collect(&:resource).compact
      end
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_dialog_kids(object, count_only, type)
    x_get_tree_generic_dialog_kids(object, count_only, type, true)
  end

  def x_get_tree_dialog_tab_kids(object, count_only, type)
    x_get_tree_generic_dialog_kids(object, count_only, type)
  end

  def x_get_tree_dialog_group_kids(object, count_only, type)
    x_get_tree_generic_dialog_kids(object, count_only, type)
  end
end
