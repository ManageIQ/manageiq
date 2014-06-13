class TreeBuilderOpsDiagnostics < TreeBuilderOps

  private

  def tree_init_options(tree_name)
    {
      :open_all => true,
      :leaf     => "Diagnostics"
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix      => "diagnostics_",
        :autoload       => true
    )
  end
end
