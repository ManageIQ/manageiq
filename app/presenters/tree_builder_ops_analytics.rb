class TreeBuilderOpsAnalytics < TreeBuilderOps
  private

  def tree_init_options(_tree_name)
    {
      :open_all => true,
      :leaf     => "Analytics",
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "analytics_",
      :autoload  => true
    )
  end
end
