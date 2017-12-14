module MiqAeServiceMiqProvisionQuotaMixin
  extend ActiveSupport::Concern
  included do
    expose(:check_quota)
  end
end
