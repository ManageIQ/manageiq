class ApplicationHelper::Button::VmMiqRequestNew < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = _('No Infrastructure Provider that supports VM provisioning added') unless provisioning_supported?
    @error_message.present?
  end

  private

  def provisioning_supported?
    EmsInfra.all.any?(&:supports_provisioning?)
  end
end
