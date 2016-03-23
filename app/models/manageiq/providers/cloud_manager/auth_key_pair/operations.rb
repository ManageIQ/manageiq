module ManageIQ::Providers::CloudManager::AuthKeyPair::Operations
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def raw_delete_key_pair
      raise NotImplementedError, _("raw_delete_key_pair must be implemented in a subclass")
    end

    def validate_delete_key_pair
      validate_unsupported(_("Delete KeyPair Operation"))
    end

    private

    # TODO(maufart): move validations to a separate place and make it more generic for better reuse?
    def validate_unsupported(message_prefix)
      self.class.validate_unsupported(message_prefix)
    end

    def validation_failed(operation, reason)
      self.class.validation_failed(operation, reason)
    end

    def validate_key_pair
      self.class.validate_key_pair(resource)
    end
  end

  module ClassMethods
    def raw_create_key_pair(_ext_management_system, _options = {})
      raise NotImplementedError, "raw_create_key_pair must be implemented in a subclass"
    end

    def validate_create_key_pair(_ext_management_system, _options)
      validate_unsupported(_("Create KeyPair Operation"))
    end

    # TODO(maufart): make it more generic or move to EMS (validate_resource?)
    def validate_key_pair(ext_management_system)
      if ext_management_system.nil?
        return {:available => false,
                :message   => _("The Keypair is not connected to an active %{table}") %
                  {:table => ui_lookup(:table => "ext_management_system")}}
      end
      {:available => true, :message => nil}
    end

    def validate_unsupported(message_prefix)
      {:available => false,
       :message   => _("%{message} is not available for %{name}.") % {:message => message_prefix, :name => name}}
    end

    def validation_failed(operation, reason)
      {:available => false,
       :message   => _("Validation failed for #{name} operation %{operation}. %{reason}") % {:operation => operation,
                                                                                             :reason    => reason}}
    end
  end
end
