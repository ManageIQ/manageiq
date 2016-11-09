class ApplicationHelper::Toolbar::DialogCenter < ApplicationHelper::Toolbar::Basic
  button_group('dialog_vmdb', [
    select(
      :dialog_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :dialog_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Dialog'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::DialogAction),
        button(
          :dialog_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Dialog'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::DialogAction),
        button(
          :dialog_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Dialog'),
          N_('Remove Dialog'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Dialog will be permanently removed!"),
          :klass     => ApplicationHelper::Button::DialogAction),
      ]
    ),
  ])
  button_group('dialog_add', [
    select(
      :dialog_add_choice,
      'pficon pficon-add-circle-o fa-lg',
      N_('Add'),
      nil,
      :enabled => true,
      :items   => [
        button(
          :dialog_add_tab,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Tab to this Dialog'),
          t,
          :url_parms => "?typ=tab&id=\#{@edit[:rec_id]}",
          :klass     => ApplicationHelper::Button::DialogAddTab),
        button(
          :dialog_add_box,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Box to this Tab'),
          t,
          :url_parms => "?typ=box&id=\#{@edit[:rec_id]}",
          :klass     => ApplicationHelper::Button::DialogAddBox),
        button(
          :dialog_add_element,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Element to this Box'),
          t,
          :url_parms => "?typ=element&id=\#{@edit[:rec_id]}",
          :klass     => ApplicationHelper::Button::DialogAddElement),
      ]
    ),
  ])
  button_group('dialog_discard', [
    button(
      :dialog_res_discard,
      'pficon pficon-close fa-lg',
      proc do
        _('Discard this new %{dialog_type}') % {:dialog_type => @sb[:node_typ].titleize}
      end,
      nil,
      :url_parms => "?id=\#{@edit[:rec_id]}",
      :klass     => ApplicationHelper::Button::DialogResDiscard),
  ])
  button_group('dialog_edit_delete', [
    button(
      :dialog_resource_remove,
      'pficon pficon-delete fa-lg',
      proc do
        _('Delete selected %{dialog_resource}') % {:dialog_resource => @sb[:txt]}
      end,
      nil,
      :url_parms => "?id=\#{@edit[:rec_id]}",
      :klass     => ApplicationHelper::Button::DialogResourceRemove),
  ])
end
