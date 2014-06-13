module MiqAeMethodService
  class MiqAeServiceServiceResource < MiqAeServiceModelBase
    expose :service_template, :association => true
    expose :service,          :association => true
    expose :resource,         :association => true
    expose :source,           :association => true
  end
end
