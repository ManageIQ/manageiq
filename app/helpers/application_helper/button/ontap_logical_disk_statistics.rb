class ApplicationHelper::Button::OntapLogicalDiskStatistics < ApplicationHelper::Button::Ontap
  needs :@record

  def disabled?
    @error_message = _('No Statistics collected for this Logical Disk') unless metrics?
    @error_message.present?
  end
end
