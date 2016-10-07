module CloudNetwork::Operations
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def validate_unsupported(message_prefix)
      self.class.validate_unsupported(message_prefix)
    end
    private :validate_unsupported

    def validation_failed(operation, reason)
      self.class.validation_failed(operation, reason)
    end
    private :validation_failed

    def validate_network
      self.class.validate_network(ext_management_system)
    end
    private :validate_network
  end

  module ClassMethods
    def validate_network(ext_management_system)
      available = true
      message = nil
      if ext_management_system.nil?
        available = false
        message = _("The Network is not connected to an active %{table}") % {
          :table => ui_lookup(:table => "ext_management_systems")
        }
      end
      {:available => available, :message => message}
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
