module AuthorizationMessagesMixin
  private

  def notify_about_unauthorized_items(item, table)
    if @view.extras[:total_count] && @view.extras[:auth_count] &&
       @view.extras[:total_count] > @view.extras[:auth_count]
      @bottom_msg = _('* You are not authorized to view ') +
                    pluralize(@view.extras[:total_count] - @view.extras[:auth_count],
                              _("other %{items}") % {:items => item.singularize}) +
                    _(' on this ') + table
    end
  end
end
