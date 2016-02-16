class ApplicationHelper::Toolbar::ServicetemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('catalogitem_vmdb', [
    select(
      :catalogitem_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :atomic_catalogitem_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Catalog Item'),
          t),
        button(
          :catalogitem_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Catalog Bundle'),
          t),
        button(
          :catalogitem_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Item to edit'),
          N_('Edit Selected Item'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :catalogitem_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Items from the VMDB'),
          N_('Remove Items from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('catalogitem_policy', [
    select(
      :catalogitem_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :catalogitem_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected Items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
