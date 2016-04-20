class TreeBuilderComplianceHistory < TreeBuilder
  def initialize(name, type, sandbox, build = true, root = nil)
    sandbox[:ch_root] = TreeBuilder.build_node_id(root) if root
    @root = root
    unless @root
       model, id = TreeBuilder.extract_node_model_and_id(sandbox[:ch_root])
       @root = model.constantize.find_by(:id => id)
    end
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :add_root => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => 'h_',
                  :open_close_all_on_dbl_click => true,
    )
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    count_only_or_objects(count_only, @root.compliances.order("timestamp DESC").limit(10))
  end

  def x_get_compliance_kids(parent, count_only)
    kids = count_only ? 0 : []
   # parent = @root.compliances.order("timestamp DESC").limit(10).find_index {|a| a.id == parent.id}
    if parent.compliance_details.empty?
      kids = {:id    => "#{parent[:key]}-nopol",
              :text  => _("No Compliance Policies Found"),
              :image => "#{parent[:key]}-nopol",
              :tip   => nil}
    else
      kids = parent.compliance_details.order("miq_policy_desc, condition_desc")
    end
    count_only_or_objects(count_only, kids)
  end

  def x_get_compliance_detail_kids(parent, count_only)
    count_only ? 0 : []
    #TODO hash nodes
  end
end
