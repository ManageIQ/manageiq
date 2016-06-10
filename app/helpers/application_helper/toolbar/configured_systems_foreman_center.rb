class ApplicationHelper::Toolbar::ConfiguredSystemsForemanCenter < ApplicationHelper::Toolbar::Basic
  include ApplicationHelper::Toolbar::ConfiguredSystem::LifecycleMixin
  include ApplicationHelper::Toolbar::ConfiguredSystem::PolicyMixin
end
