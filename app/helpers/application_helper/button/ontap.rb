class ApplicationHelper::Button::Ontap < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    ::Settings.product.smis
  end

  def disabled?
    @error_message = _('No Statistics Collected') unless metrics?
    @error_message.present?
  end

  private

  def metrics?
    @record.latest_derived_metrics
  end
end
