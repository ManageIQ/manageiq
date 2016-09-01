module GenericObjectDefinitionHelper
  TOOLBAR_CLASSES = [
    ApplicationHelper::Toolbar::XHistory,
    ApplicationHelper::Toolbar::GenericObjectDefinition,
    ApplicationHelper::Toolbar::BlankView,
  ]

  def toolbar_from_hash
    toolbar_builder = _toolbar_builder

    TOOLBAR_CLASSES.collect do |toolbar_class|
      toolbar_builder.call_by_class(toolbar_class)
    end
  end
end
