module MiqAeServiceCustomAttributeMixin
  extend ActiveSupport::Concern

  included do
    expose :custom_keys, :method => :miq_custom_keys
    expose :custom_get,  :method => :miq_custom_get
    expose :custom_set,  :method => :miq_custom_set, :override_return => true
  end
end
