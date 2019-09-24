module AvailabilityMixin
  extend ActiveSupport::Concern

  # PLEASE PREFER supports_feature_mixin.rb OVER THIS
  #
  # UI Button Validation Methods
  #
  # The UI calls this method to determine if a feature is supported for this model
  # and determines if a button should be displayed.  This method should return
  # false if the feature is not supported.  This method should return true
  # even if a function is not 'currently' available due to some condition that
  # is not being met.
  #
  # For example: If the VM needs credentials to be scanning, but they are not
  # available this method should still return true.  The UI will call the method
  # 'is_available_now_error_message' to determine if the button should be available
  # or greyed-out.  However, if the VM is a type that we cannot scan or we cannot get
  # to the storage to scan it then this method would be expected to return false.

  class_methods do
    def is_available?(request_type, *args)
      # please prefer supports_feature_mixin.rb over this
      validate_method = "validate_#{request_type}"
      send(validate_method, *args)[:available]
    end

    # Returns an error message string if there is an error.
    # Otherwise nil to indicate no errors.
    def is_available_now_error_message(request_type, *args)
      # please prefer supports_feature_mixin.rb over this
      send("validate_#{request_type}", *args)[:message]
    end
  end

  included do
    include ClassMethods
  end
end
