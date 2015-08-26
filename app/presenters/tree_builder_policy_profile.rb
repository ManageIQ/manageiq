class TreeBuilderPolicyProfile < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "pp_",
      :autoload  => true,
    )
  end
end
