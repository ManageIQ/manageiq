module MiqAeEngine
  INFRASTRUCTURE = 'infrastructure'.freeze
  CLOUD          = 'cloud'.freeze
  UNKNOWN        = 'unknown'.freeze

  class MiqAeBuiltinMethod
    ATTRIBUTE_LIST = %w(
      vm
      orchestration_stack
      miq_request
      miq_provision
      miq_host_provision
      vm_migrate_task
      platform_category
    ).freeze

    class << self
      DEFAULT_TYPE = :string

      # Define a new builtin for use in automate models
      #
      # Use it similarly like you would define a method. Required values are expressed using
      # arguments. Argument "obj" is considered to be the $evm.object. Any other argument is
      # considered an input, where it will pull out the value from inputs hash based on the name.
      # For backwards compatibility, argument "inputs" will receive all inputs.
      #
      # You can specify the input types using metadata (TODO: elaborate)
      #
      # ==== Attributes
      #
      # * +name+ - Name of the builtin. Symbol.
      # * +metadata+ - Metadata. Hash.
      #
      # ==== Examples
      #
      #   # This one takes the $evm.object and pulls "foo" out of inputs
      #   builtin :mybuiltin do |obj, foo|
      #     do_something
      #   end
      def builtin(name, metadata = {}, &block)
        @builtins ||= {}
        $miq_ae_logger.warn("Overwriting builtin method #{name}") if @builtins.include?(name)
        @builtins[name.to_s] = [block, metadata]
      end

      # Invokes a builtin on obj with inputs.
      #
      # Raises MiqAeException::MethodNotFound if the builtin was not found.
      #
      # ==== Attributes
      #
      # * +name+ - Name of the builtin to invoke. Symbol.
      # * +obj+ - Object to invoke the builtin on.
      # * +inputs+ - Inputs to pass to the method. Hash
      def invoke_builtin(name, obj, inputs)
        meth, metadata = get_builtin(name)
        required_params = (metadata[:required] || []).collect(&:to_s)
        # Detect missing required parameters
        missing_required_params = required_params - inputs.keys
        unless missing_required_params.empty?
          raise MiqAeException::MethodParmMissing, "Built-In method [#{name}] requires parameters #{required_params.inspect}, but only #{missing_required_params.inspect} were passed"
        end
        # Taking only :opt, we do not care about :rest
        meth_params = meth.parameters.select { |pt, _| pt == :opt } .collect do |_, param_name|
          param_name = param_name.to_s
          if param_name == 'obj'
            obj
          elsif param_name == 'inputs'
            # Backwards compatibility
            inputs
          else
            # Param is present or the param is not required so nil is placed in there
            inputs[param_name]
          end
        end
        instance_exec(*meth_params, &meth)
      end

      # Returns a list of all defined builtins
      def builtins
        @builtins ||= {}
        @builtins.keys
      end

      # Checks whether any builtin with such name exists.
      #
      # ==== Attributes
      #
      # * +name+ - Name of the builtin to check. Symbol
      def builtin?(name)
        builtins.include?(name.to_s)
      end

      # Returns a list of known inputs that the builtin method takes
      #
      # The format of result is [[:inputname, :inputtype], ...]
      #
      # ==== Attributes
      #
      # * +name+ - Name of the builtin to check. Symbol
      def builtin_inputs(name)
        meth, meta = get_builtin(name)
        types = meta[:types] || {}
        meth.parameters.collect(&:last).reject { |m| m =~ /^obj|inputs$/ } .collect do |input|
          [input, types[input] || DEFAULT_TYPE]
        end
      end

      # Returns whether the builtin takes the "inputs" and therefore it is not detectable what
      # inputs exactly does it take.
      #
      # ==== Attributes
      #
      # * +name+ - Name of the builtin to check. Symbol
      def builtin_legacy_inputs?(name)
        meth = get_builtin(name).first
        !meth.parameters.collect(&:last).select { |m| m == :inputs } .empty?
      end

      private

      def get_builtin(name)
        name = name.to_s
        raise MiqAeException::MethodNotFound, "Built-In Method [#{name}] does not exist" unless builtin?(name)
        @builtins[name]
      end
    end

    # Here you can define your builtins and also helper classmethods to support them

    builtin :log_object do |obj|
      $miq_ae_logger.info("===========================================")
      $miq_ae_logger.info("Dumping Object")

      $miq_ae_logger.info("Listing Object Attributes:")
      obj.attributes.sort.each { |k, v|  $miq_ae_logger.info("\t#{k}: #{v}") }
      $miq_ae_logger.info("===========================================")
    end

    builtin :log_workspace do |obj|
      $miq_ae_logger.info("===========================================")
      $miq_ae_logger.info("Dumping Workspace")
      $miq_ae_logger.info(obj.workspace.to_expanded_xml)
      $miq_ae_logger.info("===========================================")
    end

    builtin :send_email do |to, from, subject, body|
      MiqAeMethodService::MiqAeServiceMethods.send_email(to, from, subject, body)
    end

    builtin :snmp_trap_v1 do |inputs|
      MiqAeMethodService::MiqAeServiceMethods.snmp_trap_v1(inputs)
    end

    builtin :snmp_trap_v2 do |inputs|
      MiqAeMethodService::MiqAeServiceMethods.snmp_trap_v2(inputs)
    end

    builtin :service_now_eccq_insert do |server, username, password, agent, queue, topic, name, source, payload|
      if payload.nil?
        MiqAeMethodService::MiqAeServiceMethods.service_now_eccq_insert(
          server, username, password, agent, queue, topic, name, source)
      else
        MiqAeMethodService::MiqAeServiceMethods.service_now_eccq_insert(
          server, username, password, agent, queue, topic, name, source, *payload)
      end
    end

    builtin :powershell do |script, returns|
      MiqAeMethodService::MiqAeServiceMethods.powershell(script, returns)
    end

    builtin :parse_provider_category do |obj|
      provider_category = nil
      ATTRIBUTE_LIST.detect { |attr| provider_category = category_for_key(obj, attr) }
      $miq_ae_logger.info("Setting provider_category to: #{provider_category}")

      obj.workspace.root["ae_provider_category"] = provider_category || UNKNOWN

      prepend_vendor(obj)
    end

    builtin :parse_automation_request do |obj|
      obj['target_component'], obj['target_class'], obj['target_instance'] =
        case obj['request']
        when 'vm_provision'   then %w(VM   Lifecycle Provisioning)
        when 'vm_retired'     then %w(VM   Lifecycle Retirement)
        when 'vm_migrate'     then %w(VM   Lifecycle Migrate)
        when 'host_provision' then %w(Host Lifecycle Provisioning)
        when 'configured_system_provision'
          obj.workspace.root['ae_provider_category'] = 'infrastructure'
          %w(Configured_System Lifecycle Provisioning)
        end
      $miq_ae_logger.info("Request:<#{obj['request']}> Target Component:<#{obj['target_component']}> ")
      $miq_ae_logger.info("Target Class:<#{obj['target_class']}> Target Instance:<#{obj['target_instance']}>")
    end

    builtin :host_and_storage_least_utilized do |obj|
      prov = obj.workspace.get_obj_from_path("/")['miq_provision']
      raise MiqAeException::MethodParmMissing, "Provision not specified" if prov.nil?

      vm = prov.vm_template
      ems = vm.ext_management_system
      raise "EMS not found for VM [#{vm.name}" if ems.nil?
      min_running_vms = nil
      result = {}
      ems.hosts.each do |h|
        next unless h.power_state == "on"
        nvms = h.vms.collect { |v| v if v.power_state == "on" }.compact.length
        if min_running_vms.nil? || nvms < min_running_vms
          storages = h.writable_storages.find_all { |s| s.free_space > vm.provisioned_storage } # Filter out storages that do not have enough free space for the Vm
          s = storages.sort { |a, b| a.free_space <=> b.free_space }.last
          unless s.nil?
            result["host"]    = h
            result["storage"] = s
            min_running_vms   = nvms
          end
        end
      end

      ["host", "storage"].each { |k| obj[k] = result[k] } unless result.empty?
    end

    builtin :event_action_refresh do |obj, target|
      event_object_from_workspace(obj).refresh(target, false)
    end

    builtin :event_action_refresh_sync do |obj, target|
      event_object_from_workspace(obj).refresh(target, true)
    end

    builtin :event_action_refresh do |obj, target|
      event_object_from_workspace(obj).refresh(target)
    end

    builtin :event_action_policy do |obj, target, policy_event, param|
      event_object_from_workspace(obj).policy(target, policy_event, param)
    end

    builtin :event_action_scan do |obj, target|
      event_object_from_workspace(obj).scan(target)
    end

    builtin :src_vm_as_template do |obj, flag|
      event_object_from_workspace(obj).src_vm_as_template(flag)
    end

    builtin :change_event_target_state do |obj, target, param|
      event_object_from_workspace(obj).change_event_target_state(target, param)
    end

    builtin :src_vm_destroy_all_snapshots do |obj|
      event_object_from_workspace(obj).src_vm_destroy_all_snapshots
    end

    builtin :src_vm_disconnect_storage do |obj|
      event_object_from_workspace(obj).src_vm_disconnect_storage
    end

    builtin :src_vm_refresh_on_reconfig do |obj|
      event_object_from_workspace(obj).src_vm_refresh_on_reconfig
    end

    builtin :event_enforce_policy do |obj|
      event_object_from_workspace(obj).process_evm_event
    end

    def self.event_object_from_workspace(obj)
      event = obj.workspace.get_obj_from_path("/")['event_stream']
      raise MiqAeException::MethodParmMissing, "Event not specified" if event.nil?
      event
    end
    private_class_method :event_object_from_workspace

    def self.vm_detect_category(prov_obj_source)
      return nil unless prov_obj_source.respond_to?(:cloud)
      prov_obj_source.cloud ? CLOUD : INFRASTRUCTURE
    end
    private_class_method :vm_detect_category

    def self.detect_platform_category(platform_category)
      platform_category == 'infra' ? INFRASTRUCTURE : platform_category
    end
    private_class_method :detect_platform_category

    def self.detect_category(obj_name, prov_obj)
      case obj_name
      when "orchestration_stack"
        CLOUD
      when "miq_host_provision"
        INFRASTRUCTURE
      when "miq_request", "miq_provision", "vm_migrate_task"
        vm_detect_category(prov_obj.source) if prov_obj
      when "vm"
        vm_detect_category(prov_obj) if prov_obj
      else
        UNKNOWN
      end
    end
    private_class_method :detect_category

    def self.category_for_key(obj, key)
      if key == "platform_category"
        key_object = obj.workspace.root
        detect_platform_category(key_object[key]) if key_object[key]
      else
        key_object = obj.workspace.root[key]
        detect_category(key, key_object) if key_object
      end
    end
    private_class_method :category_for_key

    def self.prepend_vendor(obj)
      vendor = nil
      ATTRIBUTE_LIST.detect { |attr| vendor = detect_vendor(obj.workspace.root[attr], attr) }
      if vendor
        $miq_ae_logger.info("Setting prepend_namespace to: #{vendor}")
        obj.workspace.prepend_namespace = vendor
      end
    end
    private_class_method :prepend_vendor

    def self.detect_vendor(src_obj, attr)
      return unless src_obj
      case attr
      when "orchestration_stack"
        src_obj.type.split('::')[2]
      when "miq_host_provision"
        "vmware"
      when "miq_request", "miq_provision", "vm_migrate_task"
        src_obj.source.try(:vendor)
      when "vm"
        src_obj.try(:vendor)
      end
    end
  end
end
