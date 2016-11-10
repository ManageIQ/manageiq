class ApplicationHelper::Button::MiqAeDomainDelete < ApplicationHelper::Button::MiqAeDomainEdit
  needs :@record

  def disabled?
    @error_message = N_('Read Only Domain cannot be deleted.') if super
    @error_message.present?
  end
end
