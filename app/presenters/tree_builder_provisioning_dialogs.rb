class TreeBuilderProvisioningDialogs < TreeBuilderAeCustomization
  private

  def tree_init_options(_tree_name)
    {:leaf => "MiqDialog", :open_all => true}
  end

  def root_options
    [t = _("All Dialogs"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = MiqDialog::DIALOG_TYPES.sort.collect do |typ|
      {
        :id    => "MiqDialog_#{typ[1]}",
        :text  => typ[0],
        :image => "100/folder.png",
        :tip   => typ[0]
      }
    end
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    objects = MiqDialog.where(:dialog_type => object[:id].split('_').last).sort_by { |a| a.description.downcase }
    count_only_or_objects(count_only, objects)
  end
end
