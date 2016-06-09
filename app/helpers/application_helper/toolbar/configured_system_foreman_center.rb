class ApplicationHelper::Toolbar::ConfiguredSystemForemanCenter < ApplicationHelper::Toolbar::Basic
  include ApplicationHelper::Toolbar::ConfiguredSystem::LifecycleMixin
  include ApplicationHelper::Toolbar::ConfiguredSystem::PolicyMixin
end
