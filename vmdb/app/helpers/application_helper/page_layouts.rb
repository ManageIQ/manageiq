module ApplicationHelper::PageLayouts

  def layout_uses_listnav?
    if !(@layout == "dashboard" && ["show","change_tab","auth_error"].include?(controller.action_name) ||
         @layout == "report" ||
         @layout == "exception" ||
         @layout == "chargeback" ||
         @layout.starts_with?("miq_request") ||
         ["configuration","about","diagnostics","rss","server_build","product_update",
          "my_tasks","my_ui_tasks","all_tasks","all_ui_tasks","miq_ae_tools","miq_policy",
          "miq_ae_export","miq_ae_automate_button","miq_ae_logs","miq_policy_logs",
          "miq_policy_export","ops","pxe"].include?(@layout)) &&
       @showtype != "dialog_provision"
      return true
    else
      return false
    end
  end

  def layout_uses_tabs?
    if (["timeline"].include?(@layout) && ! @in_a_form) || ["login","authenticate","auth_error"].include?(controller.action_name) ||
       @layout == "exception" ||
       (@layout == "report" && ["new","create","edit","copy","update","explorer"].include?(controller.action_name))
      return false
    elsif @layout == "dashboard" # Dashboard tabs are located in taskbar because they are otherwise hidden behind the taskbar regardless of z-index -->
      return false
    end
    return true
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

end
