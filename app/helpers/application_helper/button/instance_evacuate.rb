class ApplicationHelper::Button::InstanceEvacuate < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = @record.unsupported_reason(:evacuate) unless @record.supports_evacuate?
    @error_message.present?
  end
end
