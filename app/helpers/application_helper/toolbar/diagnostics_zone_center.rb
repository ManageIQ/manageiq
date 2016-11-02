class ApplicationHelper::Toolbar::DiagnosticsZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    button(
      :reload_server_tree,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
  ])
  button_group('ldap_domain_vmdb', [
    select(
      :zone_configuration_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :zone_delete_server,
          'pficon pficon-delete fa-lg',
          t = proc do
            _('Delete Server %{server_name} [%{server_id}]') % {:server_name => @record.name, :server_id => @record.id}
          end,
          t,
          :confirm => proc do
                        _("Do you want to delete Server %{server_name} [%{server_id}]?") % {
                          :server_name => @record.name,
                          :server_id   => @record.id
                        }
                      end
        ),
        button(
          :zone_role_start,
          'fa fa-play-circle-o fa-lg',
          proc do
            _('Start the %{server_role_description} Role on Server %{server_name} [%{server_id}]') % {
              :server_role_description => @record.server_role.description,
              :server_name             => @record.miq_server.name,
              :server_id               => @record.miq_server.id
            }
          end,
          N_('Start Role'),
          :confirm => proc do
                        _("Start the %{server_role_description} Role on Server %{server_name} [%{server_id}]?") % {
                          :server_role_description => @record.server_role.description,
                          :server_name             => @record.miq_server.name,
                          :server_id               => @record.miq_server.id
                        }
                      end,
          :klass => ApplicationHelper::Button::RolePowerOptions
        ),
        button(
          :zone_role_suspend,
          'fa fa-pause-circle-o fa-lg',
          proc do
            _('Suspend the %{server_role_description} Role on Server %{server_name} [%{server_id}]') % {
              :server_role_description => @record.server_role.description,
              :server_name             => @record.miq_server.name,
              :server_id               => @record.miq_server.id
            }
          end,
          N_('Suspend Role'),
          :confirm => proc do
                        _("Suspend the %{server_role_description} Role on Server %{server_name} [%{server_id}]?") % {
                          :server_role_description => @record.server_role.description,
                          :server_name             => @record.miq_server.name,
                          :server_id               => @record.miq_server.id
                        }
                      end,
          :klass => ApplicationHelper::Button::RolePowerOptions
        ),
        button(
          :zone_demote_server,
          'pficon pficon-delete fa-lg',
          proc do
            _('Demote Server %{server_name} [%{server_id}] to secondary for the %{server_role_description} Role') % {
              :server_role_description => @record.server_role.description,
              :server_name             => @record.miq_server.name,
              :server_id               => @record.miq_server.id
            }
          end,
          N_('Demote Server'),
          :confirm => N_("Do you want to demote this Server to secondary?  This will leave no primary Server for this Role."),
          :klass => ApplicationHelper::Button::ServerLevelOptions
        ),
        button(
          :zone_promote_server,
          'product product-migrate fa-lg',
          proc do
            _('Promote Server %{server_name} [%{server_id}] to primary for the %{server_role_description} Role') % {
              :server_role_description => @record.server_role.description,
              :server_name             => @record.miq_server.name,
              :server_id               => @record.miq_server.id
            }
          end,
          N_('Promote Server'),
          :confirm => N_("Do you want to promote this Server to primary?  This will replace any existing primary Server for this Role."),
          :klass => ApplicationHelper::Button::ServerLevelOptions
        ),
      ]
    ),
    select(
      :zone_collect_logs_choice,
      'fa fa-filter fa-lg',
      N_('Collect Logs'),
      N_('Collect'),
      :items => [
        button(
          :zone_collect_current_logs,
          'fa fa-filter fa-lg',
          N_('Collect the current logs from the selected Zone'),
          N_('Collect current logs'),
          :klass => ApplicationHelper::Button::CollectLogs
        ),
        button(
          :zone_collect_logs,
          'fa fa-filter fa-lg',
          N_('Collect all logs from the selected Zone'),
          N_('Collect all logs'),
          :klass => ApplicationHelper::Button::CollectLogs
        ),
      ]
    ),
    button(
      :zone_log_depot_edit,
      'pficon pficon-edit fa-lg',
      N_('Edit the Log Depot settings for the selected Zone'),
      N_('Edit')),
  ])
end
