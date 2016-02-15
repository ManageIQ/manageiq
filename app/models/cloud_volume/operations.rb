module CloudVolume::Operations
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def validate_attach_volume
      validate_unsupported("Attach Volume Operation")
    end

    def validate_detach_volume
      validate_unsupported("Detach Volume Operation")
    end

    private

    def validate_unsupported(message_prefix)
      self.class.validate_unsupported(message_prefix)
    end

    def validation_failed(operation, reason)
      self.class.validation_failed(operation, reason)
    end

    def validate_volume
      self.class.validate_volume(ext_management_system)
    end

    def validate_volume_available
      msg = validate_volume
      return {:available => msg[:available], :message => msg[:message]} unless msg.nil?
      return {:available => true, :message => nil} if status == "available"
      {:available => false, :message => "The volume can't be attached, status has to be 'available'"}
    end

    def validate_volume_in_use
      msg = validate_volume
      return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
      return {:available => true, :message => nil} if status == "in-use"
      {:available => false, :message => "The volume can't be detached, status has to be 'in-use'"}
    end
  end

  module ClassMethods
    def validate_volume(ext_management_system)
      if ext_management_system.nil?
        return {:available => false,
                :message   => "The Volume is not connected to an active #{ui_lookup(:table => "ext_management_systems")}"}
      end
      {:available => true, :message => nil}
    end

    def validate_unsupported(message_prefix)
      {:available => false, :message => "#{message_prefix} is not available for #{name}."}
    end

    def validation_failed(operation, reason)
      {:available => false,
       :message   => "Validation failed for #{name} operation #{operation}. #{reason}"}
    end
  end
end
