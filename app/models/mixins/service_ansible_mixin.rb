module ServiceAnsibleMixin
  extend ActiveSupport::Concern

  class_methods do
    def with_applied_config_info(actions, config_info, opts = nil)
      actions.each do |action|
        next unless config_info[action]
        opts ? (yield action, opts) : (yield action)
      end
    end
  end
end
