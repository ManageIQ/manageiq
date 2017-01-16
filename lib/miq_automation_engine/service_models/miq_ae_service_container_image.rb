module MiqAeMethodService
  class MiqAeServiceContainerImage < MiqAeServiceModelBase
    expose :container_image_registry,     :association => true
    expose :ext_management_system,        :association => true
    expose :containers,                   :association => true
    expose :container_nodes,              :association => true
    expose :container_groups,             :association => true
    expose :container_projects,           :association => true
    expose :guest_applications,           :association => true
    expose :computer_system,              :association => true
    expose :operating_system,             :association => true
    expose :openscap_result,              :association => true
    expose :openscap_rule_results,        :association => true
    expose :exposed_ports,                :association => true
    expose :environment_variables,        :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
