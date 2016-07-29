module MiqAeServiceInflectorMixin
  extend ActiveSupport::Concern
  included do
    expose :provider_name
    expose :manager_type
  end
end
