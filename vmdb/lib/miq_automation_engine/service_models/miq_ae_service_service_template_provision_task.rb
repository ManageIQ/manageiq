module MiqAeMethodService
  class MiqAeServiceServiceTemplateProvisionTask < MiqAeServiceMiqRequestTask
    expose :service_resource, :association => true

    def dialog_options
      options[:dialog] || {}
    end

    def get_dialog_option(key)
      dialog_options[key]
    end

    def group_sequence_run_now?
      ar_method { @object.group_sequence_run_now? }
    end

    def set_dialog_option(key, value)
      ar_method do
        @object.options[:dialog] ||= {}
        @object.options[:dialog][key] = value
        @object.update_attribute(:options, @object.options)
      end
    end

    def status
      ar_method do
        if ['finished', 'provisioned'].include?(@object.state)
          @object.status.to_s.downcase
        else
          'retry'
        end
      end
    end

    def provisioned(msg)
      object_send(:update_and_notify_parent, :state => 'provisioned', :message => msg)
    end

  end
end
