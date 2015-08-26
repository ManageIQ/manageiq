class TreeBuilderEvent < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ev_",
    )
  end
end
