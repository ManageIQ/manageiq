module MiqAeMethodService
  class MiqAeServiceService < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_retirement_mixin"
    include MiqAeServiceRetirementMixin
    require_relative "mixins/miq_ae_service_custom_attribute_mixin"
    include MiqAeServiceCustomAttributeMixin

    expose :retire_service_resources
    expose :automate_retirement_entrypoint
    expose :service_resources, :association => true
    expose :service_template,  :association => true
    expose :start
    expose :stop
    expose :suspend
    expose :shutdown_guest
    expose :vms,                       :association => true
    expose :direct_vms,                :association => true
    expose :indirect_vms,              :association => true
    expose :root_service,              :association => true
    expose :all_service_children,      :association => true
    expose :direct_service_children,   :association => true
    expose :indirect_service_children, :association => true
    expose :parent_service,            :association => true
    expose :tenant,                    :association => true

    CREATE_ATTRIBUTES = [:name, :description, :service_template]

    def self.create(options = {})
      attributes = options.symbolize_keys.slice(*CREATE_ATTRIBUTES)
      if attributes[:service_template]
        raise ArgumentError, "service_template must be a MiqAeServiceServiceTemplate" unless
          attributes[:service_template].kind_of?(MiqAeMethodService::MiqAeServiceServiceTemplate)
        attributes[:service_template] = ServiceTemplate.find(attributes[:service_template].id)
      end
      ar_method { MiqAeServiceModelBase.wrap_results(Service.create!(attributes)) }
    end

    def dialog_options
      @object.options[:dialog] || {}
    end

    def get_dialog_option(key)
      dialog_options[key]
    end

    def set_dialog_option(key, value)
      ar_method do
        @object.options[:dialog] ||= {}
        @object.options[:dialog][key] = value
        @object.update_attribute(:options, @object.options)
      end
    end

    def name=(new_name)
      ar_method do
        @object.name = new_name
        @object.save
      end
    end

    def description=(new_description)
      ar_method { @object.update_attribute(:description, new_description) }
    end

    def display=(display)
      ar_method do
        @object.display = display
        @object.save
      end
    end

    def parent_service=(service)
      ar_method do
        if service
          raise ArgumentError, "service must be a MiqAeServiceService" unless service.kind_of?(
            MiqAeMethodService::MiqAeServiceService)
          @object.service = Service.find(service.id)
        else
          @object.service = nil
        end
        @object.save
      end
    end

    def owner=(owner)
      if owner.nil? || owner.kind_of?(MiqAeMethodService::MiqAeServiceUser)
        if owner.nil?
          @object.evm_owner = nil
        else
          @object.evm_owner = User.find_by_id(owner.id)
        end
        @object.save
      end
    end

    def remove_from_vmdb
      _log.info "Removing #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}>"
      object_send(:destroy)
      @object = nil
      true
    end

    def group=(group)
      if group.nil? || group.kind_of?(MiqAeMethodService::MiqAeServiceMiqGroup)
        if group.nil?
          @object.miq_group = nil
        else
          @object.miq_group = MiqGroup.find_by_id(group.id)
        end
        @object.save
      end
    end
  end
end
