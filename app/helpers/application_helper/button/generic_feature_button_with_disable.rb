class ApplicationHelper::Button::GenericFeatureButtonWithDisable < ApplicationHelper::Button::GenericFeatureButton
  needs :@record

  def disabled?
    @error_message = begin
                      @record.unsupported_reason(@feature) unless @record.supports?(@feature)
                    rescue SupportsFeatureMixin::UnknownFeatureError
                      # TODO: remove with deleting AvailabilityMixin module
                      @record.is_available_now_error_message(@feature) unless @record.is_available?(@feature)
                    end
    @error_message.present?
  end
end
