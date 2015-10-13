module ServiceTemplate::Filter
  extend ActiveSupport::Concern

  module ClassMethods
    def include_service_template?(parent_svc_task, service_template_id, parent_svc = nil)
      attrs = {'request' => 'SERVICE_PROVISION_INFO', 'message' => 'include_service'}
      st = ServiceTemplate.find(service_template_id)
      user = parent_svc_task.get_user
      obj_array = [user, st, parent_svc, parent_svc_task]
      MiqAeEngine.set_automation_attributes_from_objects(obj_array, attrs)
      uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => parent_svc_task)
      automate_result_include_service_template?(uri, user, st.name)
    end

    def automate_result_include_service_template?(uri, user, name)
      ws = MiqAeEngine.resolve_automation_object(uri, user)
      result = ws.root['include_service'].nil? ? true : ws.root['include_service']
      _log.info("Include Service Template <#{name}> : <#{result}>")
      result
    end
  end
end
