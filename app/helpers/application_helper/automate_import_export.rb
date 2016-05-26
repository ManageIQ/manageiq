module ApplicationHelper::AutomateImportExport
  def git_import_submit_options
    options = {
      :id    => "git-url-import",
      :class => "btn btn-default"
    }

    if (!MiqRegion.my_region.role_active?("git_owner"))
      options[:disabled] = true
      options[:title] = "Git Owner role not enabled, enable it in Settings -> Configuration"
    end

    options
  end
end
