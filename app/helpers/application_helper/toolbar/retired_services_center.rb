class ApplicationHelper::Toolbar::RetiredServicesCenter < ApplicationHelper::Toolbar::Basic
  include ApplicationHelper::Toolbar::Service::VmdbMixin
  include ApplicationHelper::Toolbar::Service::PolicyMixin
end
