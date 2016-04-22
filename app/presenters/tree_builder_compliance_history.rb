class TreeBuilderComplianceHistory < TreeBuilder
  def node_builder
    TreeNodeBuilderComplianceHistory
  end

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
     :add_root => false,
     :lazy     => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => 'h_',
                  :cfme_no_click               => true,
                  :open_close_all_on_dbl_click => true,
                  :onclick                     => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    count_only_or_objects(count_only, @root.compliances.order("timestamp DESC").limit(10))
  end

  def x_get_compliance_kids(parent, count_only)
    kids = []
    #binding.pry
    if parent.compliance_details.empty?
      node = {:id    => "#{parent.id}-nopol",
              :text  => _("No Compliance Policies Found"),
              :image => "#{parent.id}-nopol",
              :tip   => nil,}
      kids.push(node)
    else
      # node must be unique
      parent.compliance_details.order("miq_policy_desc, condition_desc").each do |node|
        kids.push(node) unless kids.find {|s| s.miq_policy_id == node.miq_policy_id }
      end
    end
    count_only_or_objects(count_only, kids)
  end

  def x_get_compliance_detail_kids(parent, count_only, parents)
    kids = []
    model, id = TreeBuilder.extract_node_model_and_id(parents.first)
    grandpa = model.constantize.find_by(:id => from_cid(id))
    grandpa.compliance_details.order("miq_policy_desc, condition_desc").each do |node|
       if node.miq_policy_id == parent.miq_policy_id
         n = {:id    => "#{parent.id}-p_#{node.miq_policy_id}",
              :text  => "<b>" + _("Condition: ") + "</b>" + node.condition_desc,
              :image => node.condition_result ? "check" : "x",
              :tip   => nil}
         kids.push(n)
       end
    end
    count_only_or_objects(count_only, kids)
  end

  def x_get_tree_custom_kids(parent, count_only, _options)
    count_only ? 0 : []
  end
end
