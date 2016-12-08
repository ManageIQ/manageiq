class ApplicationHelper::Button::InstanceMiqRequestNew < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = _('No Cloud Provider that supports instance provisioning added') unless provisioning_supported?
    @error_message.present?
  end

  private

  def provisioning_supported?
    EmsCloud.all.any?(&:supports_provisioning?)
  end
end
