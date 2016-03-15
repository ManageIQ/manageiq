class ApplicationHelper::Toolbar::XEditView < ApplicationHelper::Toolbar::Basic
  button_group('form_buttons', [
    button(
      :button_add,
      'pficon pficon-add-circle-o fa-lg',
      t = N_('Add'),
      t,
      :url       => "\#{@edit[:url]}",
      :url_parms => "?button=add"),
    button(
      :button_save,
      'fa fa-floppy-o fa-lg',
      N_('Save Changes'),
      N_('Save'),
      :url       => "\#{@edit[:url]}",
      :url_parms => "?button=save"),
    button(
      :button_reset,
      'fa fa-reply fa-lg',
      t = N_('Reset'),
      t,
      :url       => "\#{@edit[:url]}",
      :url_parms => "?button=reset"),
    button(
      :button_cancel,
      'fa fa-ban fa-lg',
      N_('Cancel Changes'),
      N_('Cancel'),
      :url       => "\#{@edit[:url]}",
      :url_parms => "?button=cancel"),
  ])
end
