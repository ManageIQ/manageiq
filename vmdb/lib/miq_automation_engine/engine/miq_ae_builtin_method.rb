module MiqAeEngine
  # All Class Methods beginning with miq_ are callable from the engine
  class MiqAeBuiltinMethod
    def self.miq_log_object(obj, inputs)
      $miq_ae_logger.info("===========================================")
      $miq_ae_logger.info("Dumping Object")

      $miq_ae_logger.info("Listing Object Attributes:")
      obj.attributes.sort.each { |k, v|  $miq_ae_logger.info("\t#{k}: #{v}")}
      $miq_ae_logger.info("===========================================")
    end

    def self.miq_log_workspace(obj, inputs)
      $miq_ae_logger.info("===========================================")
      $miq_ae_logger.info("Dumping Workspace")
      $miq_ae_logger.info(obj.workspace.to_expanded_xml)
      $miq_ae_logger.info("===========================================")
    end

    def self.miq_send_email(obj, inputs)
      MiqAeMethodService::MiqAeServiceMethods.send_email(inputs["to"], inputs["from"], inputs["subject"], inputs["body"])
    end

    def self.miq_snmp_trap_v1(obj, inputs)
      MiqAeMethodService::MiqAeServiceMethods.snmp_trap_v1(inputs)
    end

    def self.miq_snmp_trap_v2(obj, inputs)
      MiqAeMethodService::MiqAeServiceMethods.snmp_trap_v2(inputs)
    end

    def self.miq_oracle_stored_procedure(obj, inputs)
      if inputs['params'].nil?
        MiqAeMethodService::MiqAeServiceMethods.oracle_stored_procedure(inputs['database'], inputs['username'], inputs['password'], inputs['procedure_name'] )
      else
        MiqAeMethodService::MiqAeServiceMethods.oracle_stored_procedure(inputs['database'], inputs['username'], inputs['password'], inputs['procedure_name'], *(inputs['params']) )
      end
    end

    def self.miq_service_now_eccq_insert(obj, inputs)
      if inputs['payload'].nil?
        MiqAeMethodService::MiqAeServiceMethods.service_now_eccq_insert(inputs['server'], inputs['username'], inputs['password'], inputs['agent'], inputs['queue'], inputs['topic'], inputs['name'], inputs['source'] )
      else
        MiqAeMethodService::MiqAeServiceMethods.service_now_eccq_insert(inputs['server'], inputs['username'], inputs['password'], inputs['agent'], inputs['queue'], inputs['topic'], inputs['name'], inputs['source'], *(inputs['payload']) )
      end
    end

    def self.powershell(obj, inputs)
      MiqAeMethodService::MiqAeServiceMethods.powershell(inputs['script'], inputs['returns'])
    end

    def self.miq_host_and_storage_least_utilized(obj, inputs)
      prov = obj.workspace.get_obj_from_path("/")['miq_provision']
      raise MiqAeException::MethodParmMissing,"Provision not specified" if prov.nil?

      vm = prov.vm_template
      ems = vm.ext_management_system
      raise "EMS not found for VM [#{vm.name}" if ems.nil?
      min_running_vms = nil
      result = Hash.new
      ems.hosts.each { |h|
        next unless h.power_state == "on"
        nvms = h.vms.collect { |v| v if v.power_state == "on" }.compact.length
        if min_running_vms.nil? || nvms < min_running_vms
          storages = h.storages.find_all { |s| s.free_space > vm.provisioned_storage } # Filter out storages that do not have enough free space for the Vm
          s = storages.sort { |a,b| a.free_space <=> b.free_space }.last
          unless s.nil?
            result["host"]    = h
            result["storage"] = s
            min_running_vms   = nvms
          end
        end
      }

      ["host", "storage"].each { |k| obj[k] = result[k] } unless result.empty?
    end

    def self.miq_event_action_refresh(obj, inputs)
      event_object_from_workspace(obj).refresh(inputs['target'])
    end

    def self.miq_event_action_policy(obj, inputs)
      event_object_from_workspace(obj).policy(inputs['target'], inputs['policy_event'], inputs['param'])
    end

    def self.miq_event_action_scan(obj, inputs)
      event_object_from_workspace(obj).scan(inputs['target'])
    end

    def self.miq_src_vm_as_template(obj, inputs)
      event_object_from_workspace(obj).src_vm_as_template(inputs['flag'])
    end

    def self.miq_change_event_target_state(obj, inputs)
      event_object_from_workspace(obj).change_event_target_state(inputs['target'], inputs['param'])
    end

    def self.miq_src_vm_destroy_all_snapshots(obj, _inputs)
      event_object_from_workspace(obj).src_vm_destroy_all_snapshots
    end

    def self.miq_src_vm_disconnect_storage(obj, _inputs)
      event_object_from_workspace(obj).src_vm_disconnect_storage
    end

    def self.miq_src_vm_refresh_on_reconfig(obj, _inputs)
      event_object_from_workspace(obj).src_vm_refresh_on_reconfig
    end

    def self.event_object_from_workspace(obj)
      event = obj.workspace.get_obj_from_path("/")['ems_event']
      raise MiqAeException::MethodParmMissing, "Event not specified" if event.nil?
      event
    end
    private_class_method :event_object_from_workspace
  end
end
