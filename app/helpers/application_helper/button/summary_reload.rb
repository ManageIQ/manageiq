class ApplicationHelper::Button::SummaryReload < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def visible?
    @explorer && ((@record && proper_layout? && proper_showtype?) || @lastaction == 'show_list')
  end

  private

  def proper_layout?
    @layout != 'miq_policy_rsop'
  end

  def proper_showtype?
    !%w(details item).include?(@showtype)
  end
end
