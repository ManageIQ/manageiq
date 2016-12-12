class ApplicationHelper::Button::MiqAeDomainLock < ApplicationHelper::Button::MiqAeDomain
  needs :@record

  def disabled?
    @error_message = _('Domain is Locked.') if super
    @error_message.present?
  end

  def visible?
    super || @record.lockable?
  end
end
