class ApplicationHelper::Toolbar::PxeImageTypesCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_type_vmdb', [
    select(
      :pxe_image_type_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :pxe_image_type_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new System Image Type'),
          t,
          :klass => ApplicationHelper::Button::ButtonNewDiscover),
        button(
          :pxe_image_type_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single System Image Type to edit'),
          N_('Edit the selected System Image Type'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :pxe_image_type_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected System Image Types'),
          N_('Remove System Image Types'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected System Image Types will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
