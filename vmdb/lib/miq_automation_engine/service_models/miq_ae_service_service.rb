module MiqAeMethodService
  class MiqAeServiceService < MiqAeServiceModelBase
    expose :retire_now
    expose :start
    expose :stop
    expose :suspend
    expose :shutdown_guest
    expose :vms
    expose :direct_vms
    expose :indirect_vms
    expose :root_service
    expose :all_service_children
    expose :direct_service_children
    expose :indirect_service_children
    expose :parent_service

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

    def retires_on=(date)
      ar_method do
        @object.retires_on = date
        @object.save
      end
    end

    def retirement_warn=(seconds)
      ar_method do
        @object.retirement_warn = seconds
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
      $log.info "MIQ(#{self.class.name}#remove_from_vmdb) Removing #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}>"
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
