class ApplicationHelper::Toolbar::ArbitrationProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('arbitration_profile_cloud_vmdb', [
                 select(
                   :arbitration_profile_vmdb_choice,
                   'fa fa-cog fa-lg',
                   t = N_('Configuration'),
                   t,
                   :items => [
                     button(
                       :arbitration_profile_new,
                       'pficon pficon-edit fa-lg',
                       N_('Add a new Arbitration Profile'),
                       N_('Add a new Arbitration Profile'),
                       :klass => ApplicationHelper::Button::ButtonNewDiscover),
                     button(
                       :arbitration_profile_edit,
                       'pficon pficon-edit fa-lg',
                       N_('Select a single Arbitration Profile to edit'),
                       N_('Edit Selected Arbitration Profile'),
                       :url_parms => "main_div",
                       :enabled   => false,
                       :onwhen    => "1"),
                     button(
                       :arbitration_profile_delete,
                       'pficon pficon-delete fa-lg',
                       N_('Remove selected Arbitration Profiles from the VMDB'),
                       N_('Remove Arbitration Profiles from the VMDB'),
                       :url_parms => "main_div",
                       # rubocop:disable LineLength
                       :confirm   => N_("Warning: The selected Cloud Providers and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Cloud Providers?"),
                       :enabled   => false,
                       :onwhen    => "1+"),
                   ]
                 ),
               ]
              )
end
