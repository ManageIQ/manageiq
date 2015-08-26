class TreeBuilderAlertProfile < TreeBuilder
  private

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ap_",
      :autoload  => true,
    )
  end
end
