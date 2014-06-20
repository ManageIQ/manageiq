class SupportController < ApplicationController

# # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
# verify  :method => :post, :only => [ :destroy, :create, :update ],
#    :redirect_to => { :action => :index }

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    about
    render :action=>"show"
  end

  def show
  end

  def about
#   @tabs ||= [ ["1", ""] ]
#   @tabs.push( ["1", "Help"] )
    session[:vmdb] ||= Hash.new
    session[:vmdb][:version] ||= VMDB::Config.VERSION
    session[:vmdb][:build]   ||= VMDB::Config.BUILD
    @temp[:user_role] = User.current_user.miq_user_role_name
    @layout = "about"
  end

  private ############################

  def get_layout
    ["about", "diagnostics"].include?(session[:layout]) ? session[:layout] : "about"
  end

  def get_session_data
    @title  = "Support"
    @layout = get_layout
  end

  def set_session_data
    session[:layout] = @layout
  end

end
