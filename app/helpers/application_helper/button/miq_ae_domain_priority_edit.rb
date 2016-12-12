class ApplicationHelper::Button::MiqAeDomainPriorityEdit < ApplicationHelper::Button::MiqAeDefaultNoRecord
  def disabled?
    if User.current_tenant.visible_domains.length < 2
      @error_message = _('You need two or more domains to edit domain priorities')
    end
    @error_message.present?
  end
end
