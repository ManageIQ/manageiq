module GenericObjectHelper
  TOOLBAR_CLASSES = [
    ApplicationHelper::Toolbar::XHistory,
    ApplicationHelper::Toolbar::GenericObjectDefinition
  ].freeze

  def toolbar_from_hash
    TOOLBAR_CLASSES.collect do |toolbar_class|
      _toolbar_builder.build_by_class(toolbar_class)
    end
  end
end
