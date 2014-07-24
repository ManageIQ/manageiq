class SummaryPresenter
  include ActionView::Helpers::TextHelper   # we need 'pluralize(num, word)'
  include ApplicationHelper                 # role_allows
  include ActionView::Helpers::DateHelper   # time_ago_in_words
  include ActionView::Helpers::NumberHelper # number_with_delimiter

  def initialize(record, params, session)
    @record  = record
    @params  = params
    @session = session
  end

  def session # for role_allows
    @session
  end

  protected

  include VmHelper # last_date*

  def help
    Helper.instance
  end

  class Helper
    include Singleton
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers
    include ActionDispatch::Routing
    include Rails.application.routes.url_helpers
  end

  def controller_name
    @params[:controller]
  end

  def link_to(arg1, arg2, arg3)
    arg2 = arg2.merge(:controller => @params[:controller]) unless arg2.key?(:controller)
    help.link_to(arg1, arg2, arg3)
  end

  def url_for(arg)
    arg = arg.merge(:controller => @params[:controller]) unless arg.key?(:controller)
    help.url_for(arg)
  end
end
