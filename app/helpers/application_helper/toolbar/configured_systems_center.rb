class ApplicationHelper::Toolbar::ConfiguredSystemsCenter < ApplicationHelper::Toolbar::Basic
  include ApplicationHelper::Toolbar::ConfiguredSystem::LifecycleMixin
  include ApplicationHelper::Toolbar::ConfiguredSystem::PolicyMixin
end
