class ApplicationHelper::Button::GenericFeatureButtonWithDisable < ApplicationHelper::Button::GenericFeatureButton
  needs :@record

  def disabled?
    @error_message = if @record.feature_known?(@feature)
                       unless @record.supports?(@feature)
                         @record.unsupported_reason(@feature)
                       end
                     else
                       # TODO: remove with deleting AvailabilityMixin module
                       unless @record.is_available?(@feature)
                         @record.is_available_now_error_message(@feature)
                       end
                     end
    @error_message.present?
  end
end
