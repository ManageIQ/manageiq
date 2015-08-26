class TreeBuilderAction < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ac_",
    )
  end
end
