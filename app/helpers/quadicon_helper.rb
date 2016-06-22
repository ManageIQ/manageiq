module QuadiconHelper
  # render a quadicon
  #   size: size of the quadicon
  #   item: element to be represented
  #   typ:  type of view (:listnav, ....?) # FIXME: find possible values
  #   db:   name of the model of item
  #   row:
  #   height:
  #   mode:
  def render_quadicon(item, options)
    return unless item

    options.reverse_merge! :size => 72
    options[:db] ||= db_from_item(item)

    id = "quadicon_#{item.id}"
    style, cls = if options[:typ] == :listnav
                   options[:height] ||= 80
                   ["margin-left: auto; margin-right: auto; width: 75px; height: #{options[:height]}px; z-index: 0;", '']
                 else
                   ['', 'quadicon']
                 end

    content_tag(:div, :style => style, :id => id, :class => cls) do
      partial_name = partial_name_from_item(item)

      case partial_name
      when 'cim_base_storage_extent', 'cim_storage_extent', 'ontap_file_share',
           'ontap_logical_disk', 'ontap_storage_system', 'ontap_storage_volume',
           'snia_local_file_system' then
                                        flobj_img_simple(options[:size], "#{options[:size]}/#{partial_name}.png")
      when 'service', 'service_template', 'service_ansible_tower', 'service_template_ansible_tower' then
                                        render_service_quadicon(item, options)
      when 'resource_pool'         then render_resource_pool_quadicon(item, options)
      when 'host'                  then render_host_quadicon(item, options)
      when 'ext_management_system' then render_ext_management_system_quadicon(item, options)
      when 'ems_cluster'           then render_ems_cluster_quadicon(item, options)
      when 'single_quad'           then render_single_quad_quadicon(item, options)
      when 'storage'               then render_storage_quadicon(item, options)
      when 'vm_or_template'        then render_vm_or_template_quadicon(item, options)
      end
    end
  end

  def img_for_compliance(item)
    case item.passes_profiles?(session[:policies].keys)
    when true  then '100/check.png'
    when 'N/A' then '100/na.png'
    else            '100/x.png'
    end
  end

  def img_for_vendor(item)
    "svg/vendor-#{h(item.vendor)}.svg"
  end

  def img_for_auth_status(item)
    img = case item.authentication_status
          when "Invalid" then "x"
          when "Valid"   then "checkmark"
          when "None"    then "unknown"
          else "exclamationpoint"
          end
    "100/#{h(img)}.png"
  end

  def img_for_host_vendor(item)
    "svg/vendor-#{h(item.vmm_vendor_display.downcase)}.svg"
  end

  def render_quadicon_text(item, row)
    return unless item
    db = db_from_item(item)

    if @embedded && !@showlinks
      column = case db
               when "MiqCimInstance"   then 'evm_display_name'
               when "ConfiguredSystem" then 'hostname'
               else 'name'
               end
      content_tag(:span, :title => h(row[column])) do
        truncate_for_quad(h(row[column]))
      end
    else
      if !@listicon.nil? && (@vm || @host || @storage)
        # if sub-item is being shown
        if @listicon == "scan_history"
          href_link = url_for_item_quad_text(@vm, @id, @listicon.pluralize)
          link_to(truncate_for_quad(row['started_on'].to_s),
                  href_link, :title => h(row['started_on']))
        else
          href_link = if @vm
                        url_for_item_quad_text(@vm, @id, @listicon.pluralize)
                      elsif @host
                        url_for_item_quad_text(@host, @id, @listicon.pluralize)
                      elsif @storage
                        url_for_item_quad_text(@storage, @id, params[:action])
                      end
          link_to(truncate_for_quad(row['name'] ? row['name'] : row['display_name']),
                  href_link, :title => h(row['name']))
        end

      elsif @policy_sim && !session[:policies].empty?
        # Policy sim (VMs only, for now)
        link_to(truncate_for_quad(row['name']),
                url_for_db(db), :title => _("Show policy details for %s") % row['name'])
      elsif db == "EmsCluster"
        link_to(truncate_for_quad(row['v_qualified_desc']),
                url_for_db("ems_cluster", "show"), :title => h(row['v_qualified_desc']))
      elsif db == "StorageManager"
        link_to(truncate_for_quad(row['name']),
                url_for_db("storage_manager", "show"), :title => h(row['name']))
      elsif db == "FloatingIp"
        link_to(truncate_for_quad(item.address),
                url_for_db(db, "show"), :title => h(item.address))
      else
        if @explorer
          column = case db
                   when "ServiceResource"      then 'resource_name'
                   when "ConfiguredSystem"     then 'hostname'
                   when "ConfigurationProfile" then 'description'
                   else 'name'
                   end
          name = row[column]

          if request.parameters[:controller] == "service" && @view.db == "Vm"
            attributes = vm_quad_link_attributes(item)
            if attributes[:link]
              link_to(
                truncate_for_quad(name),
                {:controller => attributes[:controller], :action => attributes[:action], :id => attributes[:id]},
                :title                 => name,
                "data-miq_sparkle_on"  => true,
                "data-miq_sparkle_off" => true
              )
            else
              link_to(truncate_for_quad(name), nil, h(name))
            end
          else
            link_to(
              truncate_for_quad(name),
              {:action => 'x_show', :id => controller.send(:list_row_id, row)},
              "data-miq_sparkle_on"  => true,
              "data-miq_sparkle_off" => true,
              :title                 => name,
              "data-method"          => :post,
              :remote                => true
            )
          end
        else
          if row['evm_display_name']
            link_to(truncate_for_quad(row['evm_display_name']), url_for_db(db, "show"), :title => h(row['evm_display_name']))
          elsif row['key']
            link_to(truncate_for_quad(row['key']), url_for_db(db), :title => h(row['key']))
          else
            link_to(truncate_for_quad(row['name']), url_for_db(db, "show", item), :title => h(row['name']))
          end
        end
      end
    end
  end

  private

  def db_from_item(item)
    item.kind_of?(ExtManagementSystem) ? item.class.db_name : item.class.base_model.name
  end

  def partial_name_from_item(item)
    partial_name = if %w(EmsCluster ResourcePool Repository Service ServiceTemplate
                     Storage ServiceAnsibleTower ServiceTemplateAnsibleTower).include?(item.class.name)
                     item.class.name.underscore
                   elsif item.kind_of?(VmOrTemplate)
                     item.class.base_model.to_s.underscore
                   elsif item.kind_of?(ManageIQ::Providers::ConfigurationManager)
                     "single_quad"
                   elsif %w(ExtManagementSystem Host).include?(item.class.base_class.name)
                     item.class.base_class.name.underscore
                   else
                     # All other models that only need single large icon and use name for hover text
                     "single_quad"
                   end

    partial_name = 'vm_or_template' if %w(miq_template vm).include?(partial_name)
    partial_name
  end

  # Truncate text to fit below a quad icon
  TRUNC_AT = 13
  TRUNC_TO = 10
  def truncate_for_quad(value)
    return value.to_s if value.to_s.length < TRUNC_AT
    case @settings.fetch_path(:display, :quad_truncate)
    when "b" then value.first(TRUNC_TO) + "..."
    when "f" then "..." + value.last(TRUNC_TO)
    else          value.first(TRUNC_TO / 2) + "..." + value.last(TRUNC_TO / 2)
    end
  end

  def url_for_item_quad_text(record, id, action)
    url_for(:controller => controller_for_model(record.class),
            :action     => action,
            :id         => record.id.to_s,
            :show       => id.to_s)
  end

  def flobj_img_simple(size, image = nil, cls = '')
    image ||= "#{size}/base-single.png"

    content_tag(:div, :class => "flobj #{cls}") do
      tag(:img, :border => 0, :src => ActionController::Base.helpers.image_path(image),
          :width => size, :height => size)
    end
  end

  def link_nowhere(image, text, size)
    link_to(image_tag(image, :border => 0, :width => size, :height => size), '', :title => h(text))
  end

  def render_service_quadicon(item, options)
    size = options[:size]
    output = []
    output << flobj_img_simple(size)

    fname = ActionController::Base.helpers.image_path(item.decorate.listicon_image)
    output << content_tag(:div, :class => "flobj e#{size}") do
      if !@embedded || @showlinks
        link_to(image_tag(fname, :width => size, :height => size, :title => h(item.name)),
          {:action => 'x_show', :id => to_cid(item.id)},
          "data-miq_sparkle_on"  => true,
          "data-miq_sparkle_off" => true,
          "data-method"          => :post,
          :remote                => true)
      else
        link_nowhere(fname, item.name, size)
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def render_resource_pool_quadicon(item, options)
    img = item.vapp ? "vapp.png" : "resource_pool.png"
    size = options[:size]
    width = options[:size] == 150 ? 54 : 35
    output = []

    output << flobj_img_simple(options[:size])
    output << flobj_img_simple(width * 1.8, "100/#{img}", "e#{size}")
    output << flobj_img_simple(size, '100/shield.png', "g#{size}") unless item.get_policies.empty?

    unless options[:typ] == :listnav
      # listnav, no clear image needed
      output << content_tag(:div, :class => "flobj") do
        fname = ActionController::Base.helpers.image_path('clearpix.gif')
        if !@embedded || @showlinks
          link_to(image_tag(fname, :width => size, :height => size),
                  url_for_record(item), :title => h(item.name))
        else
          link_nowhere(fname, item.name, size)
        end
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def flobj_p_simple(cls, text)
    content_tag(:div, :class => "flobj #{cls}") do
      content_tag(:p, text)
    end
  end

  def render_host_quadicon(item, options)
    size = options[:size]
    width = options[:size] == 150 ? 54 : 35
    output = []

    if settings(:quadicons, :host)
      output << flobj_img_simple(size, "#{size}/base.png")

      output << flobj_p_simple("a#{size}", item.vms.size)
      output << flobj_img_simple(size, "72/currentstate-#{h(item.state.downcase)}.png", "b#{size}") unless item.state.blank?
      output << flobj_img_simple(size, img_for_host_vendor(item), "c#{size}")
      output << flobj_img_simple(size, img_for_auth_status(item), "d#{size}")
      output << flobj_img_simple(size, '100/shield.png', "g#{size}") unless item.get_policies.empty?
    else
      output << flobj_img_simple(size)
      output << flobj_img_simple(width * 1.8, img_for_host_vendor(item), "e#{size}")
    end

    if options[:typ] == :listnav
      # Listnav, no href needed
      output << content_tag(:div, :class => 'flobj') do
        tag(:img, :src => ActionController::Base.helpers.image_path("#{options[:size]}/reflection.png"), :border => 0)
      end
    else
      href = if !@embedded || @showlinks
               @edit && @edit[:hostitems] ? "/host/edit/?selected_host=#{item.id}" : url_for_record(item)
             end

      output << content_tag(:div, :class => 'flobj') do
        link_to(
          image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                    :border => 0, :width => size, :height => size),
          href,
          :title => _("Name: %s | Hostname: %s") % [h(item.name), h(item.hostname)]
        )
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def render_ext_management_system_quadicon(item, options)
    size = options[:size]
    width = options[:size] == 150 ? 54 : 35
    output = []

    if settings(:quadicons, db_for_quadicon)
      output << flobj_img_simple(size, "#{size}/base.png")
      output << flobj_p_simple("a#{size}", item.kind_of?(EmsCloud) ? item.total_vms : item.hosts.size)
      output << flobj_p_simple("b#{size}", item.total_miq_templates) if item.kind_of?(EmsCloud)
      output << flobj_img_simple(size, "svg/vendor-#{h(item.image_name)}.svg", "c#{size}")
      output << flobj_img_simple(size, img_for_auth_status(item), "d#{size}")
      output << flobj_img_simple(size, '100/shield.png', "g#{size}") unless item.get_policies.empty?
    else
      output << flobj_img_simple(size, "#{size}/base-single.png")
      output << flobj_img_simple(width * 1.8, "svg/vendor-#{h(item.image_name)}.svg", "e#{size}")
    end

    if options[:typ] == :listnav
      output << flobj_img_simple(size, "#{size}/reflection.png")
    else
      output << content_tag(:div, :class => 'flobj') do
        t = [h(item.name), h(item.hostname), h(item.last_refresh_status.titleize)]
        link_to(
          image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                    :border => 0, :width => size, :height => size),
          url_for_record(item),
          :title => _("Name: %s | Hostname: %s | Refresh Status: %s") % t
        )
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def render_ems_cluster_quadicon(item, options)
    size = options[:size]
    output = []

    output << flobj_img_simple(size, "#{size}/base-single.png")
    output << flobj_img_simple(size * 1.8, "100/emscluster.png", "e#{size}")
    output << flobj_img_simple(size, "100/shield.png", "g#{size}") unless item.get_policies.empty?

    unless options[:typ] == :listnav
      # Listnav, no clear image needed
      url = (!@embedded || @showlinks) ? url_for_record(item) : nil

      output << content_tag(:div, :class => 'flobj') do
        link_to(
          image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                    :border => 0, :width => size, :height => size),
          url, :title => h(item.v_qualified_desc)
        )
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def render_single_quad_quadicon(item, options)
    size = options[:size]
    output = []

    if @listicon.nil?
      img_path = if item.kind_of?(MiqCimInstance)
                   if item.kind_of?(CimStorageExtent)
                     "100/cim_base_storage_extent.png"
                   else
                     "100/#{item.class.to_s.underscore}.png"
                   end
                 elsif item.decorator_class?
                   item.decorate.try(:fonticon) || item.decorate.try(:listicon_image)
                 else
                   "100/#{item.class.base_class.to_s.underscore}.png"
                 end

      output << flobj_img_simple(size, "#{size}/base-single.png")
      output << flobj_img_simple(size, img_path, "e#{size}")

      unless options[:typ] == :listnav
        # Listnav, no clear image needed
        output << content_tag(:div, :class => "flobj") do
          name = item.kind_of?(MiqCimInstance) ? item.evm_display_name : item.name

          if !@embedded || @showlinks
            if @explorer
              link_to(
                image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                          :width => size, :height => size, :title => h(name)),
                {:action => 'x_show', :id => controller.send(:list_row_id, item)},
                "data-miq_sparkle_on"  => true,
                "data-miq_sparkle_off" => true,
                "data-method"          => :post,
                :remote                => true)
            else
              link_to(
                image_tag(ActionController::Base.helpers.image_path("clearpix.gif"),
                          :width => size, :height => size),
                url_for_record(item),
                :title => h(name)
              )
            end
          else
            link_nowhere(ActionController::Base.helpers.image_path('clearpix.gif'), name, size)
          end
        end
      end
    else
      width = size == 150 ? 54 : 35
      output << flobj_img_simple(width, "#{size}/base-single.png")
      output << flobj_img_simple(width * 1.8, "100/#{@listicon}.png", "e#{size}")

      unless options[:typ] == :listnav
        # Listnav, no clear image needed
        if !@embedded || @showlinks
          title = case @listicon
                  when "scan_history"                         then item.started_on
                  when "orchestration_stack_output", "output" then item.key
                  else item.name
                  end
          href = url_for(:controller => @parent.class.base_class.to_s.underscore,
                         :action => @lastaction, :id => @parent.id, :show => item.id)
        else
          href = nil
          title = item.name
        end

        output << content_tag(:div, :class => 'flobj') do
          link_to(
            image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                      :border => 0, :width => size, :height => size),
            href, :title => h(title)
          )
        end
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def render_storage_quadicon(item, options)
    size = options[:size]
    output = []

    if settings(:quadicons, :storage)
      output << flobj_img_simple(size, "#{size}/base.png")
      output << flobj_img_simple(size, "100/storagetype-#{item.store_type.nil? ? "unknown" : h(item.store_type.to_s.downcase)}.png", "a#{size}")
      output << flobj_p_simple("b#{size}", item.v_total_vms)
      output << flobj_p_simple("c#{size}", item.v_total_hosts)

      space_percent = item.free_space_percent_of_total == 100 ? 20 : ((item.free_space_percent_of_total.to_i + 2) / 5.25).round
      output << flobj_img_simple(size, "100/piecharts/datastore/#{h(space_percent)}.png", "d#{size}")
    else
      space_percent = (item.used_space_percent_of_total.to_i + 9) / 10
      output << flobj_img_simple(size, "#{size}/base-single.png")
      output << flobj_img_simple(size, "100/datastore-#{h(space_percent)}.png", "e#{size}")
    end

    if options[:typ] == :listnav
      # Listnav, no clear image needed
      output << flobj_img_simple(size, "#{size}/reflection.png")
    else
      if @explorer && (!@embedded || @showlinks)
        output << content_tag(:div, :class => 'flobj') do
          link_to(
            image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                      :width => size, :height => size, :title => h(item.name)),
            {:action => 'x_show', :id => to_cid(item.id)},
            "data-miq_sparkle_on"  => true,
            "data-miq_sparkle_off" => true,
            "data-method"          => :post,
            :remote                => true)
        end
      elsif @explorer && @embedded && !@showlinks
        href = nil
        output << content_tag(:div, :class => 'flobj') do
          link_to(
            image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                      :border => 0, :width => size, :height => size),
            href, :title => _("Name: %s | %s Type: %s") % [h(item.name), ui_lookup(:table => "storages"), h(item.store_type)]
          )
        end
      else
        href = !@embedded || @showlinks ? url_for_record(item) : nil

        output << content_tag(:div, :class => 'flobj') do
          link_to(
            image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                      :border => 0, :width => size, :height => size),
            href, :title => _("Name: %s | %s Type: %s") % [h(item.name), ui_lookup(:table => "storages"), h(item.store_type)]
          )
        end
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end

  def render_vm_or_template_quadicon(item, options)
    size = options[:size]
    output = []

    if settings(:quadicons, item.class.base_model.name.underscore.to_sym)
      output << flobj_img_simple(size, "#{size}/base.png")
      output << flobj_img_simple(size, "100/os-#{h(item.os_image_name.downcase)}.png", "a#{size}")
      output << flobj_img_simple(size, "72/currentstate-#{h(item.normalized_state.downcase)}.png", "b#{size}")
      output << flobj_img_simple(size, "svg/vendor-#{h(item.vendor.downcase)}.svg", "c#{size}")
      output << flobj_img_simple(size, "100/shield.png", "g#{size}") unless item.get_policies.empty?

      if @lastaction == "policy_sim"
        output << flobj_img_simple(size, img_for_compliance(item), "d#{size}") if @policy_sim && !session[:policies].empty?
      else
        output << flobj_p_simple("d#{size}", h(item.v_total_snapshots))
      end
    else
      width = options[:size] == 150 ? 54 : 35
      output << flobj_img_simple(size, "#{size}/base-single.png")
      if @policy_sim && !session[:policies].empty?
        output << flobj_img_simple(width * 1.8, img_for_compliance(item), "e#{size}")
      elsif @policy_sim
        output << flobj_img_simple(width * 1.8, img_for_vendor(item), "e#{size}")
      else
        output << flobj_img_simple(size, "#{size}/base-single.png")
        output << flobj_img_simple(width * 1.8, img_for_vendor(item), "e#{size}")
      end
    end

    unless options[:typ] == :listnav
      output << content_tag(:div, :class => 'flobj') do
        if !@embedded || @showlinks
          if @explorer
            if request.parameters[:controller] == "service" && @view.db == "Vm"
              attributes = vm_quad_link_attributes(item)
              if attributes[:link]
                link_to(
                  image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                            :width => size, :height => size, :title => h(item.name)),
                  {:controller => attributes[:controller], :action => attributes[:action], :id => attributes[:id]},
                  "data-miq_sparkle_on"  => true,
                  "data-miq_sparkle_off" => true)
              else
                link_nowhere(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                             item.name, size)
              end
            else
              link_to(
                image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                          :width => size, :height => size, :title => h(item.name)),
                {:action => 'x_show', :id => to_cid(item.id)},
                "data-miq_sparkle_on"  => true,
                "data-miq_sparkle_off" => true,
                :remote                => true,
                "data-method"          => :post)
            end
          else
            link_to(
              image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                        :border => 0, :width => size, :height => size),
              url_for_record(item), :title => h(item.name)
            )
          end
        else
          if @policy_sim && !session[:policies].empty?
            if @edit && @edit[:explorer]
              link_to(
                image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                          :width => size, :height => size, :title => h(item.name)),
                {:action => 'policies', :id => to_cid(item.id)},
                "data-miq_sparkle_on"  => true,
                "data-miq_sparkle_off" => true,
                :remote                => true,
                "data-method"          => :post)
            else
              link_to(
                image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                          :border => 0, :width => size, :height => size,
                          :title => _("Show policy details for %s") % h(item.name)),
                url_for_record(item, "policies")
              )
            end
          else
            link_to(
              image_tag(ActionController::Base.helpers.image_path("#{size}/reflection.png"),
                        :border => 0, :width => size, :height => size,
                        :title => h(item.name))
            )
          end
        end
      end
    end
    output.collect(&:html_safe).join('').html_safe
  end
end
