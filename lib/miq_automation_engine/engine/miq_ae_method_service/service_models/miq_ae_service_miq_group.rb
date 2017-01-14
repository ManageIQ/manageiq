module MiqAeMethodService
  class MiqAeServiceMiqGroup < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_custom_attribute_mixin"
    include MiqAeServiceCustomAttributeMixin

    expose :users,  :association => true
    expose :vms,    :association => true
    expose :tenant, :association => true
    expose :filters, :method => :get_filters
  end
end
