module ApplicationHelper
  module Tasks
    def task_name(task)
      case task
      when "check_compliance_queue"
        _("Check Compliance")
      when "destroy"
        _("Delete")
      when "reboot_guest"
        _("Restart Guest")
      when "retire_now"
        _("Retirement")
      when "scan"
        _("Analysis")
      when "refresh_ems"
        _("Refresh Provider")
      else
        task.titleize
      end
    end
  end
end
