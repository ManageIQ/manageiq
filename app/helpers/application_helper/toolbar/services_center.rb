class ApplicationHelper::Toolbar::ServicesCenter < ApplicationHelper::Toolbar::Basic
  include ApplicationHelper::Toolbar::Service::VmdbMixin
  include ApplicationHelper::Toolbar::Service::PolicyMixin
  include ApplicationHelper::Toolbar::Service::LifecycleMixin
end
