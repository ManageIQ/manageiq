class TreeBuilderGenericObject
  def nodes
    all_generic_object_definitions = GenericObjectDefinition.all

    children = all_generic_object_definitions.collect do |generic_object_definition|
      {
        text: generic_object_definition.name,
        href: "##{generic_object_definition.name}",
        icon: "fa fa-file-o",
        tags: ["2"],
        id:   generic_object_definition.id
      }
    end

    [{
      text: 'Generic Object Definitions',
      href: '#generic-object-definitions-root',
      tags: ['4'],
      nodes: children
    }].to_json
  end
end
