class ApplicationHelper::Toolbar::XTemplateCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('image_vmdb', [
                 select(
                   :image_vmdb_choice,
                   'fa fa-cog fa-lg',
                   t = N_('Configuration'),
                   t,
                   :items => [
                     button(
                       :image_refresh,
                       'fa fa-refresh fa-lg',
                       N_('Refresh relationships and power states for all items related to this Image'),
                       N_('Refresh Relationships and Power States'),
                       :confirm => N_("Refresh relationships and power states for all items related to this Image?")),
                     button(
                       :image_scan,
                       'fa fa-search fa-lg',
                       N_('Perform SmartState Analysis on this Image'),
                       N_('Perform SmartState Analysis'),
                       :confirm => N_("Perform SmartState Analysis on this Image?"),
                       :klass => ApplicationHelper::Button::VmInstanceTemplateScan),
                     separator,
                     button(
                       :image_edit,
                       'pficon pficon-edit fa-lg',
                       t = N_('Edit this Image'),
                       t),
                     button(
                       :image_ownership,
                       'pficon pficon-user fa-lg',
                       N_('Set Ownership for this Image'),
                       N_('Set Ownership')),
                     button(
                       :image_delete,
                       'pficon pficon-delete fa-lg',
                       N_('Remove this Image'),
                       N_('Remove Image'),
                       :url_parms => "&refresh=y",
                       :confirm   => N_("Warning: This Image and ALL of its components will be permanently removed!")),
                     separator,
                     button(
                       :image_right_size,
                       'product product-custom-6 fa-lg',
                       N_('CPU/Memory Recommendations of this Image'),
                       N_('Right-Size Recommendations')),
                     button(
                       :image_reconfigure,
                       'pficon pficon-edit fa-lg',
                       N_('Reconfigure the Memory/CPU of this Image'),
                       N_('Reconfigure this Image')),
                   ]
                 ),
               ])
  button_group('image_lifecycle', [
                 select(
                   :image_lifecycle_choice,
                   'fa fa-recycle fa-lg',
                   t = N_('Lifecycle'),
                   t,
                   :items => [
                     button(
                       :image_miq_request_new,
                       'pficon pficon-add-circle-o fa-lg',
                       t = N_('Provision Instances using this Image'),
                       t,
                       :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
                       :options => {:feature => :provisioning})
                   ]
                 ),
               ])
  button_group('image_policy', [
                 select(
                   :image_policy_choice,
                   'fa fa-shield fa-lg',
                   t = N_('Policy'),
                   t,
                   :items => [
                     button(
                       :image_protect,
                       'pficon pficon-edit fa-lg',
                       N_('Manage Policies for this Image'),
                       N_('Manage Policies')),
                     button(
                       :image_policy_sim,
                       'fa fa-play-circle-o fa-lg',
                       N_('View Policy Simulation for this Image'),
                       N_('Policy Simulation')),
                     button(
                       :image_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for this Image'),
                       N_('Edit Tags')),
                     button(
                       :image_check_compliance,
                       'fa fa-search fa-lg',
                       N_('Check Compliance of the last known configuration for this Image'),
                       N_('Check Compliance of Last Known Configuration'),
                       :confirm => N_("Initiate Check Compliance of the last known configuration for this Image?")),
                   ]
                 ),
               ])
end
