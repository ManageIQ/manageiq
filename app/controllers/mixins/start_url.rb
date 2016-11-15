module StartUrl
  extend ActiveSupport::Concern

  def start_url_for_user(start_url)
    return url_for(start_url) unless start_url.nil?
    return url_for(:controller => 'dashboard', :action => 'show') unless helpers.settings(:display, :startpage)

    first_allowed_url = nil
    startpage_already_set = nil
    MiqShortcut.start_pages.each do |url, _description, rbac_feature_name|
      allowed = start_page_allowed?(rbac_feature_name)
      first_allowed_url ||= url if allowed
      # if default startpage is set, check if it is allowed
      startpage_already_set = true if @settings[:display][:startpage] == url && allowed
      break if startpage_already_set
    end

    # user first_allowed_url in start_pages to be default page, if default startpage is not allowed
    @settings.store_path(:display, :startpage, first_allowed_url) unless startpage_already_set
    @settings[:display][:startpage]
  end
end
