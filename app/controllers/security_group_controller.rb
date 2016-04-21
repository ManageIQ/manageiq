class SecurityGroupController < ApplicationController
  include AuthorizationMessagesMixin
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericButtonMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin

  def self.display_methods
    %w(instances network_ports)
  end
end
