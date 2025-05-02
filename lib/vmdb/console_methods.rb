module Vmdb
  module ConsoleMethods
    include LogLevelToggle
    include SimulateQueueWorker

    def backtrace(include_external = false)
      caller.select { |path| include_external || path.start_with?(Rails.root.to_s) }
    end

    def set_translation_locale(locale = "en")
      I18n.locale = locale
    end

    def set_user_translation_locale(userid: "admin", locale: "en")
      user = User.find_by_userid(userid)

      user.settings[:display] = {:locale => locale}
      user.save!

      User.current_user = user
      set_translation_locale(user.settings[:display][:locale])
    end

    # Helper method to set up a $evm variable for debugging purposes in Rails console
    def automate_initialize_evm(user: nil)
      ws = MiqAeEngine::MiqAeWorkspaceRuntime.current = MiqAeEngine::MiqAeWorkspaceRuntime.new
      ws.ae_user = (user || User.find_by(:userid => 'admin'))
      $evm = MiqAeMethodService::MiqAeService.new(ws)
    end

    # Helper method to enable one or more roles from the Rails console in development mode
    #
    # Role assignment is done in the UI however activation is handled by the orchestrator.
    # In development mode, the orchestrator is typically not running. This method handles
    # both the assignment and activation of a role all at once.
    #
    # @param role_names [Array<String>] The role names to enable, defaults to all currently
    #   assigned roles. If "*" is passed, all possible roles will be enabled.
    def enable_roles(*role_names)
      raise NotImplementedError, "not implemented in #{Rails.env} mode" unless Rails.env.development?

      role_names.flatten!

      if role_names.blank?
        role_names = MiqServer.my_server.server_role_names
      elsif role_names.include?("*")
        MiqServer.my_server.server_role_names = "*"
        role_names = MiqServer.my_server.server_role_names
      else
        MiqServer.my_server.server_role_names += role_names
      end

      MiqServer.my_server.activate_roles(*role_names)
      MiqServer.my_server.active_role_names
    end

    def monitor_vmware
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?

      require 'VMwareWebService/MiqVim'
      MiqVim.cacheScope = :cache_scope_core
      MiqVim.monitor_updates = true
    end

    # when running rails s, automate can not find
    # the api server. This sets it up
    def enable_remote_ui
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?

      # essentially disabling the heartbeat since simulate_queue_worker doesn't keep this up to date
      MiqServer.my_server.update(:last_heartbeat => 1.year.from_now)
      return if MiqRegion.my_region.remote_ui_miq_server.present?

      # ensure the ip address is setup
      MiqServer.my_server.update(
        :hostname                 => "localhost",
        :ipaddress                => "127.0.0.1",
        :has_active_userinterface => true
      )

      raise "remote ui url not set" unless MiqRegion.my_region.remote_ui_miq_server.present?
    end
  end
end
