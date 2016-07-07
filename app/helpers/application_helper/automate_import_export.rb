module ApplicationHelper::AutomateImportExport
  def git_import_submit_help
    unless MiqRegion.my_region.role_active?("git_owner")
      content_tag(
        :i,
        "",
        :class => ["fa", "fa-lg", "fa-question-circle"],
        :title => "Git Owner role is not enabled, enable it in Settings -> Configuration"
      )
    end
  end
end
