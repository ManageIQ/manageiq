module AuthorizationMessagesMixin
  private

  def notify_about_unauthorized_items(item, table)
    if unauthorized_count > 0
      @bottom_msg = _('* You are not authorized to view ') +
                    pluralize(unauthorized_count, _("other %{items}") % {:items => item.singularize}) +
                    _(' on this ') + table
    end
  end

  def unauthorized_count
    @view.extras[:total_count] && @view.extras[:auth_count] ? @view.extras[:total_count] - @view.extras[:auth_count] : 0
  end
end
