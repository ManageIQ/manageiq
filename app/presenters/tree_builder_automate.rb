class TreeBuilderAutomate < TreeBuilderAeClass
  def tree_init_options(_tree_name)
    {:leaf => "datastore", :full_ids => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix    => "",
                  :onclick      => "miqOnClickSelectAETreeNode",
                  :exp_tree     => false,
                  :autoload     => true,
                  :base_id      => "root",
                  :highlighting => true)
  end

  def self.select_node_builder(controller)
    case controller
    when 'catalog'
      TreeNodeBuilderAutomateCatalog
    when 'miq_ae_class'
      TreeNodeBuilderAutomate
    end
  end
end
