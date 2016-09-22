class ApplicationHelper::Toolbar::GenericObjectDefinition < ApplicationHelper::Toolbar::Basic
  button_group('generic_object_definition', [
    select(
      :generic_object_definition_choice,
      'fa fa-cog fa-lg',
      title = N_('Configuration'),
      title,
      :items => [
        button(
          :generic_object_definition_create,
          'pficon pficon-add-circle-o fa-lg',
          title = N_('Create a new Generic Object Definition'),
          title,
          :data => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "showAddForm"}'
          }
        )
      ]
    )
  ])
end
