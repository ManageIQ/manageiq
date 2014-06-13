class AlertController < ApplicationController

  before_filter :check_privileges, :except=> [:rss]
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show_list
#   @tabs = [ ["show_list", ""], ["show_list", "RSS Feeds"], ["","E-mail"] ]
# Removed inactive "E-mail" tab - Sprint 34
    @lastaction = "show_list"
    @listtype = "rss_list"
    get_rss_feeds
    @rss_roles = ["<All>"]
    RssFeed.roles.sort.each { |r| @rss_roles.push(r.titleize)}
    @breadcrumbs = Array.new
    @rss_role = params[:role] == nil ? "<All>" : params[:role]
    if @rss_role == "<All>"
      drop_breadcrumb( {:name=>"All RSS Feeds", :url=>"/alert/show_list"})
    else
      drop_breadcrumb( {:name=>@rss_role +" RSS Feeds", :url=>"/alert/show_list"})
    end
  end

  def role_selected
    show_list
    render :update do |page|                    # Use RJS to update the display
      page.replace 'tab_div', :partial=>'rss_list'
    end
  end
  # Start a local RSS feed from a view
  def start_rss
    if params[:feed]
      @feed = params[:feed]
      @limit = params[:limit].nil? ? 10 : params[:limit].to_i
      begin
        if @feed[0..4] != "http:"       # feed is local, call the rss_feed method
          @rss_feed = SimpleRSS.parse(rss(@feed, true))
        else
          @rss_feed = SimpleRSS.parse(open(params[:feed]))          # open the external feed
        end
      rescue Exception => e
        @rss_error_title = "Problem with RSS feed: " + params[:feed]
        @rss_error_text = e.to_s
        $log.warn("MIQ(dashboard-show): [#{e.to_s}]")
      end
    else
      @rss_error_title = "Problem with RSS"
      @rss_error_text = "No feed specified"
    end
#   render :partial => 'rssfeed', :locals=>{:item=>params[:item]}
    render :update do |page|
      page.replace_html("dd_#{params[:item]}", :partial=>"rssfeed", :locals=>{:item=>params[:item]})
    end
  end

  # Render an RSS feed back to either a local or non-local reader
  def rss(feed=nil, local=false)
    feed = params[:feed] if params[:feed]
    feed_record = RssFeed.find_by_name(feed)
    if feed_record == nil
      raise "Requested feed is invalid"
    end
    proto = request.env["HTTP_REFERER"] ? request.env["HTTP_REFERER"].split("://")[0] : nil   # Get protocol from the request
    proto = nil unless [nil,"http","https"].include?(proto)                                   # Make sure it's http or https
    proto ||= session[:req_protocol]                                                          # If nil, use previously discovered value
    session[:req_protocol] ||= proto                                                          # Save protocol in session
    feed_data = feed_record.generate(request.env["HTTP_HOST"], local, proto)

    return feed_data if local
    render feed_data if ! local
  end

  private ###########################

  # fetch rss feed records
  def get_rss_feeds
    if params[:role] == nil || params[:role] == "<All>"
      @rss_feeds = RssFeed.order("title")
    else
      @rss_feeds = RssFeed.find_tagged_with(:any=>[params[:role].split.join("_").downcase], :ns=>"/managed", :cat=>"roles").order("title")
    end
  end

  def get_session_data
    @title = "RSS"
    @layout = "rss"
    @lastaction = session[:alert_lastaction]
  end

  def set_session_data
    session[:alert_lastaction] = @lastaction
  end

end
