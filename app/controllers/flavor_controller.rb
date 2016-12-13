class FlavorController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include Mixins::GenericButtonMixin
  include Mixins::GenericSessionMixin

  def self.display_methods
    %w(instances)
  end

  def download_summary_pdf
    @record = identify_record(params[:id])
    @display = "download_pdf"
    set_summary_pdf_data
  end

  menu_section :clo
end
