class TreeBuilderStorageAdapters < TreeBuilder

  def initialize(name, type, sandbox, build = true, root = nil)
#save other stuff thet is not saved in TreeBuilder
    sandbox[:sa_root] = root if root
    @root = sandbox[:sa_root]
    super(name, type, sandbox, build)
  end
  private
  #always same
  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix => 'h_',
        :click_url                   => "/vm/show/",
        :onclick                     => "miqOnClickHostNet",
        :open_close_all_on_dbl_click => true
    #change anything that is not same as in app/view/layouts/_dynatree.html.haml
    )
  end

  #set root
  def root_options
    [@root.name, _("Host: %{name}") % {:name => @root.name}, "host"]
  end

  def x_get_tree_roots(count_only = false, _options)
    kids = count_only ? 0 : []
    if !@root.hardware.nil? && @root.hardware.storage_adapters.length > 0
      kids = count_only_or_objects(count_only, @root.hardware.storage_adapters)
    end
    kids.reverse unless count_only
    kids
    end

  def x_get_tree_guest_device_kids(parent, count_only = false)
    kids = count_only ? 0 : []
    kids = count_only_or_objects(count_only, parent.miq_scsi_targets)
  end

  def x_get_tree_target_kids(parent, count_only)
    count_only_or_objects(count_only, parent.miq_scsi_luns)
  end

  def x_get_tree_lun_kids(parent, count_only)
    count_only ? 0 : []
  end

end