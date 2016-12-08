class ApplicationHelper::Button::MiqAeDomainUnlock < ApplicationHelper::Button::MiqAeDomain
  needs :@record

  def disabled?
    @error_message = _('Domain is Unlocked.') if super
    @error_message.present?
  end

  def visible?
    super || @record.unlockable?
  end
end
