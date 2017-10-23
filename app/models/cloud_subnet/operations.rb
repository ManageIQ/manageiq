module CloudSubnet::Operations
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.extend ClassMethods
  end

  module InstanceMethods
    private

    def validate_unsupported(message_prefix)
      self.class.validate_unsupported(message_prefix)
    end

    def validation_failed(operation, reason)
      self.class.validation_failed(operation, reason)
    end

    def validate_subnet
      self.class.validate_subnet(ext_management_system)
    end
  end

  module ClassMethods
    def validate_subnet(ext_management_system)
      if ext_management_system.nil?
        return {
          :available => false,
          :message   => _("The Subnet is not connected to an active Provider")
        }
      end
      {:available => true, :message => nil}
    end

    def validate_unsupported(message_prefix)
      {:available => false, :message => _("%{message} is not available for %{name}.") % {:message => message_prefix,
                                                                                         :name    => name}}
    end

    def validation_failed(operation, reason)
      {:available => false,
       :message   => _("Validation failed for %{name} operation %{operation}. %{reason}") % {:name      => name,
                                                                                             :operation => operation,
                                                                                             :reason    => reason}}
    end
  end
end
