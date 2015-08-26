class TreeBuilderPolicy < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "po_",
      :autoload  => true,
    )
  end
end
