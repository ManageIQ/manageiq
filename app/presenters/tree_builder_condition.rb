class TreeBuilderCondition < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "co_",
      :autoload  => true,
    )
  end
end
