class ApplicationHelper::Toolbar::ServicetemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('catalogitem_vmdb', [
    select(
      :catalogitem_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :onwhen => "1+",
      :items  => [
        button(
          :ab_group_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Button Group'),
          t),
        button(
          :ab_button_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Button'),
          t),
        button(
          :catalogitem_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Item'),
          t,
          :url_parms => "main_div"),
        button(
          :catalogitem_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Item from the VMDB'),
          N_('Remove Item from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Catalog Items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Catalog Item?")),
      ]
    ),
  ])
  button_group('catalogitem_policy', [
    select(
      :catalogitem_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :catalogitem_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Catalog Item'),
          N_('Edit Tags'),
          :url_parms => "main_div"),
      ]
    ),
  ])
end
