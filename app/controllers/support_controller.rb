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
    @vmdb = {:version => Vmdb::Appliance.VERSION, :build => Vmdb::Appliance.BUILD}
    @user_role = User.current_user.miq_user_role_name
    @pdf_documents = pdf_documents
    @layout = "about"
  end

  private ############################

  def get_layout
    %w(about diagnostics).include?(session[:layout]) ? session[:layout] : "about"
  end

  def get_session_data
    @title  = "Support"
    @layout = get_layout
  end

  def set_session_data
    session[:layout] = @layout
  end

  def pdf_document_files
    Dir.glob(Rails.root.join("public/doc/*.pdf"))
  end

  def pdf_documents
    pdf_document_files.sort.each_with_object({}) do |f, h|
      f = File.basename(f, ".pdf")
      h[f] = f.titleize
    end
  end

end
