class ApplicationHelper::Button::MiqAeGitRefresh < ApplicationHelper::Button::MiqAeDomain
  needs :@record

  def disabled?
    nil
  end

  def visible?
    super || (git_enabled?(@record) && GitBasedDomainImportService.available?)
  end
end
