class TreeBuilderAlert < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "al_",
    )
  end
end
