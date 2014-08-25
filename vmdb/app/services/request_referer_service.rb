class RequestRefererService
  def self.allowed_access?(request, controller_name, action_name, referer)
    new.allowed_access?(request, controller_name, action_name, referer)
  end

  def self.access_whitelisted?(request, controller_name, action_name)
    new.access_whitelisted?(request, controller_name, action_name)
  end

  ENTRY_POINTS_FLAT = {
    # For all 'show' actions below the case where ID is not found is handled in
    # record_no_longer_exists? which sets a flash message and redirects either
    # to 'explorer' or 'show_list'. Therefor we need to whitelist more then just 'show'.
    'vm_or_template' => %w(show:id explorer),  # http://localhost:3000/vm_or_template/show/400r75
    # Valid vm_or_template/show/:id redirects to {vm_infra,vm_cloud,vm_or_template}/explorer
    # the decision is done in 'controller_for_vm'.
    'vm_infra'       => %w(explorer),
    'vm_cloud'       => %w(explorer),

    'vm'             => %w(show:id show_list), # http://localhost:3000/vm/show/400r6
    'host'           => %w(show:id show_list), # http://localhost:3000/host/show/400r6
    'miq_request'    => %w(show:id show_list), # http://localhost:3000/miq_request/show/400r3
    'ems_cluster'    => %w(show:id show_list), # http://localhost:3000/ems_cluster/show/400r2
    'storage'        => %w(show:id show_list), # http://localhost:3000//storage/show/400r1
  }.freeze

  ENTRY_POINTS =
    ENTRY_POINTS_FLAT.each_with_object({}) do |(controller_name, actions), entry_points|
      actions.each do |action|
        tokens = action.split(':')
        entry_points.store_path(controller_name, tokens.shift, tokens)
      end
    end.freeze

  IE8_EXCEPTIONS = {
    # white list controller/action pairs that throw 403 Forbidden errors in IE8
    # due to the referer not being passed by IE8 itself.
    :availability_zone    => %w(
      download_data
      show_list
    ),
    :catalog              => %w(download_data),
    :chargeback           => %w(
      render_csv
      render_txt
      report_only
    ),
    :configuration        => %w(
      change_tab
      timeprofile_copy
      timeprofile_edit
      timeprofile_new
    ),
    :dashboard            => %w(
      change_group
      reset_widgets
      show
      widget_add
      widget_close
    ),
    :ems_cloud            => %w(
      download_data
      show_list
    ),
    :ems_cluster          => %w(download_data),
    :ems_infra            => %w(
      download_data
      show_list
    ),
    :flavor               => %w(
      download_data
      show_list
    ),
    :host                 => %w(download_data),
    :miq_ae_tools         => %w(fetch_log),
    :miq_capacity         => %w(planning_report_download),
    :miq_policy           => %w(fetch_log),
    :ontap_file_share     => %w(show_list),
    :ontap_logical_disk   => %w(show_list),
    :ontap_storage_system => %w(show_list),
    :ontap_storage_volume => %w(show_list),
    :repository           => %w(show_list),
    :resource_pool        => %w(show_list),
    :storage_manager      => %w(show_list),
    :vm_cloud             => %w(download_data),
    :vm_infra             => %w(download_data),
    :vm_or_template       => %w(download_data)
  }.freeze

  def allowed_access?(request, controller_name, action_name, referer)
    access_whitelisted?(request, controller_name, action_name) ||
      referer_valid?(request.referer, referer, request.headers, controller_name, action_name)
  end

  def referer_valid?(referer, saved_referer, headers, controller_name, action_name)
    return true if (referer.to_s + '/').starts_with?(saved_referer)
    ie8_referer_exception?(headers, controller_name, action_name)
  end

  def ie8_referer_exception?(headers, controller_name, action_name)
    return false unless headers['HTTP_USER_AGENT'].downcase.include?("msie 8")
    controller_sym = controller_name.to_sym
    true if IE8_EXCEPTIONS.key?(controller_sym) && IE8_EXCEPTIONS[controller_sym].include?(action_name)
  end

  # We only allow urls that have all the params specified in ENTRY_POINTS
  #
  # We use request.request_method so that HEAD becomes GET.
  #
  # The header we are testing with 'xml_http_request?' is optional. So do not
  #   trust this and make sure, that the whitelisted action sends only HTML. No JS!
  #
  def access_whitelisted?(request, controller_name, action_name)
    controller_entry_points = ENTRY_POINTS[controller_name] || {}
    request.request_method == 'GET' &&
      controller_entry_points.key?(action_name) &&
      !controller_entry_points[action_name].detect { |param| !request.parameters[param].present? } &&
      !request.xml_http_request?
  end
end
