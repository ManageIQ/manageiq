module ServiceTemplateFilter
  extend ActiveSupport::Concern

  module ClassMethods
    def include_service_template?(parent_svc_task, service_template_id, parent_svc = nil)
      attrs = {'request' => 'SERVICE_PROVISION_INFO', 'message' => 'include_service'}
      st = ServiceTemplate.find(service_template_id)
      set_automation_attrs([parent_svc_task.get_user, st, parent_svc, parent_svc_task], attrs)
      uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => parent_svc_task)
      automate_result(uri, st.name)
    end

    def automate_result(uri, name)
      ws  = MiqAeEngine.resolve_automation_object(uri)
      result = ws.root('include_service').nil? ? true : ws.root('include_service')
      $log.info("Include Service Template <#{name}> : <#{result}>")
      result
    end

    def set_automation_attrs(objects, attrs)
      Array.wrap(objects).each do |object|
        next unless object
        key   = MiqAeEngine.create_automation_attribute_key(object)
        value = MiqAeEngine.create_automation_attribute_value(object)
        attrs[key] = value
      end
    end
  end
end
