module ChildStorageManagerMixin
  extend ActiveSupport::Concern

  include BelongsToParentManagerMixin
end
