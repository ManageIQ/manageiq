module StartUrl
  extend ActiveSupport::Concern

  STORAGE_START_PAGES = %w(cim_storage_extent_show_list
                           ontap_file_share_show_list
                           ontap_logical_disk_show_list
                           ontap_storage_system_show_list
                           ontap_storage_volume_show_list
                           storage_manager_show_list).to_set.freeze
  CONTAINERS_START_PAGES = %w(ems_container_show_list
                              container_node_show_list
                              container_group_show_list
                              container_service_show_list
                              container_view).to_set.freeze

  included do
    helper_method :start_page_options
  end

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

  def start_page_options
    MiqShortcut.start_pages.each_with_object([]) do |(url, description, rbac_feature_name), result|
      result.push([description, url]) if start_page_allowed?(rbac_feature_name)
    end
  end

  private

  def start_page_allowed?(start_page)
    return false if STORAGE_START_PAGES.include?(start_page) && !::Settings.product.storage
    return false if CONTAINERS_START_PAGES.include?(start_page) && !::Settings.product.containers
    role_allows?(:feature => start_page, :any => true)
  end
end
