module MiqAeMethodService
  class MiqAeServiceTenant < MiqAeServiceModelBase
    expose :id
    expose :domain
    expose :subdomain
    expose :name
    expose :login_text
    expose :logo_file_name
    expose :logo_content_type
    expose :logo_file_size
    expose :login_logo_file_name
    expose :login_logo_content_type
    expose :login_logo_file_size
    expose :ancestry
    expose :description
  end
end
