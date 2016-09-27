module MiqAeToolsHelper
  def git_import_button_enabled?
    GitBasedDomainImportService.available?
  end

  def git_import_submit_help
    unless git_import_button_enabled?
      content_tag(
        :i,
        "",
        :class => ["fa", "fa-lg", "fa-question-circle"],
        :title => _("Please enable the git owner role in order to import git repositories")
      )
    end
  end
end
