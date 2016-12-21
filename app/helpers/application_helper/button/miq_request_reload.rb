class ApplicationHelper::Button::MiqRequestReload < ApplicationHelper::Button::Basic
  def visible?
    @lastaction == 'show_list' || @showtype == 'miq_provisions'
  end
end
