class TreeBuilderProvisioningDialogs  < TreeBuilderAeCustomization
  private

  def tree_init_options(tree_name)
    {:leaf => "MiqDialog", :open_all => true}
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    objects = MiqDialog::DIALOG_TYPES.sort.collect do |typ|
      {
        :id    => "MiqDialog_#{typ[1]}",
        :text  => typ[0],
        :image => "folder",
        :tip   => typ[0]
      }
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_custom_kids(object, options)
    objects = MiqDialog.find_all_by_dialog_type(object[:id].split('_').last).sort_by { |a| a.description.downcase }
    count_only_or_objects(options[:count_only], objects, nil)
  end
end
