module ApplicationHelper::PageLayouts
  def layout_uses_listnav?
    return false if %w(
      about
      all_tasks
      all_ui_tasks
      chargeback
      configuration
      container_dashboard
      container_topology
      diagnostics
      exception
      miq_ae_automate_button
      miq_ae_export
      miq_ae_logs
      miq_ae_tools
      miq_policy
      miq_policy_export
      miq_policy_logs
      my_tasks
      my_ui_tasks
      ops
      pxe
      report
      rss
      server_build
    ).include?(@layout)

    return false if dashboard_no_listnav?

    return false if @layout.starts_with?("miq_request")

    return false if @showtype == "dialog_provision"

    return false if controller.action_name.end_with?("tagging_edit")

    true
  end

  def layout_uses_tabs?
    if (["timeline"].include?(@layout) && ! @in_a_form) ||
       ["login", "authenticate", "auth_error"].include?(controller.action_name) ||
       @layout == "exception" ||
       (@layout == 'vm' && controller.action_name == 'edit') ||
       (@layout == "report" && ["new", "create", "edit", "copy", "update", "explorer"].include?(controller.action_name))
      return false
    elsif @layout == "dashboard" || @layout == "container_dashboard" # Dashboard tabs are located in taskbar because they are otherwise hidden behind the taskbar regardless of z-index -->
      return false
    end
    true
  end

  def layout_uses_breadcrumbs?
    !["dashboard",
      "exception",
      "support",
      "configuration",
      "rss",
      "my_tasks",
      "my_ui_tasks",
      "all_tasks",
      "all_ui_tasks"].include?(@layout)
  end

  def dashboard_no_listnav?
    @layout == "dashboard" && %w(
      auth_error
      change_tab
      show
    ).include?(controller.action_name)
  end
end
