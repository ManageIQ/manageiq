module MiqAeMethodService
  class MiqAeServiceContainerTemplate < MiqAeServiceModelBase
    expose :container_template_parameters, :association => true
    expose :ext_management_system,         :association => true
  end
end
