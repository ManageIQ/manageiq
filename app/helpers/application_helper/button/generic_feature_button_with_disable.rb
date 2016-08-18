class ApplicationHelper::Button::GenericFeatureButtonWithDisable < ApplicationHelper::Button::GenericFeatureButton
  needs_record

  def calculate_properties
    self[:enabled] = !(self[:title] = @error_message if disabled?)
  end

  def disabled?
    begin
      begin
        @error_message = @record.try(:unsupported_reason, @feature)
      rescue NoMethodError # TODO: remove with deleting AvailabilityMixin module
        @error_message = @record.try(:is_available_now_error_message, @feature) if @error_message.nil?
      end
    rescue
      @error_message = 'Feature is not supported.'
      true
    end
  end
end
