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

    if options[:typ] == :listnav
      id = ""
      options[:height] ||= 80
      style = "margin-left: auto; margin-right: auto; width: 75px; height: #{options[:height]}px; z-index: 0;"
    else
      style = ""
      id = "quadicon"
    end

    content_tag(:div, :style => style, :id => id) do
      partial_name = partial_name_from_item(item)
      # List of removed partials with two lines
      norender = %w(cim_base_storage_extent cim_storage_extent ontap_file_share ontap_logical_disk ontap_storage_system ontap_storage_volume snia_local_file_system)

      if norender.include?(partial_name)
        content_tag(:div, :class => 'flobj') do
          tag(:img, :src => ActionController::Base.helpers.image_path("#{options[:size]}/#{partial_name}.png"), :border => 0)
        end
      else
        render(
          :partial => "layouts/quadicon/#{partial_name}",
          :locals  => {
            :row   => options[:row],
            :mode  => options[:mode],
            :size  => options[:size],
            :width => options[:size] == 150 ? 54 : 35,
            :item  => item,
            :typ   => options[:typ],
            :db    => options[:db]
          }
        )
      end
    end
  end

  def img_for_compliance(item)
    result = item.passes_profiles?(session[:policies].keys)
    if result == true
      '100/check.png'
    elsif result == "N/A"
      '100/na.png'
    else
      '100/x.png'
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
          content_tag(:a, truncate_for_quad(row['started_on'].to_s),
                      :href => href_link, :title => h(row['started_on']))
        else
          href_link = if @vm
                        url_for_item_quad_text(@vm, @id, @listicon.pluralize)
                      elsif @host
                        url_for_item_quad_text(@host, @id, @listicon.pluralize)
                      elsif @storage
                        url_for_item_quad_text(@storage, @id, params[:action])
                      end
          content_tag(:a, truncate_for_quad(row['name'] ? row['name'] : row['display_name']),
                      :href => href_link, :title => h(row['name']))
        end

      elsif @policy_sim && session[:policies].length > 0
        # Policy sim (VMs only, for now)
        content_tag(:a, truncate_for_quad(row['name']),
                    :href => url_for_db(db), :title => _("Show policy details for %s") % row['name'])
      elsif db == "EmsCluster"
        content_tag(:a, truncate_for_quad(row['v_qualified_desc']),
                    :href => url_for_db("ems_cluster", "show"), :title => h(row['v_qualified_desc']))
      elsif db == "StorageManager"
        content_tag(:a, truncate_for_quad(row['name']),
                    :href => url_for_db("storage_manager", "show"), :title => h(row['name']))
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
              content_tag(:a, truncate_for_quad(name), :title => h(name))
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
            content_tag(:a, truncate_for_quad(row['evm_display_name']), :href => url_for_db(db, "show"), :title => h(row['evm_display_name']))
          elsif row['key']
            content_tag(:a, truncate_for_quad(row['key']), :href => url_for_db(db), :title => h(row['key']))
          else
            content_tag(:a, truncate_for_quad(row['name']), :href => url_for_db(db, "show", item), :title => h(row['name']))
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
    partial_name = if %w(EmsCluster ResourcePool Repository Service ServiceTemplate Storage).include?(item.class.name)
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

    # VMs and miq_templates use the same partial
    partial_name = 'vm_or_template' if %w(miq_template vm).include?(partial_name)

    partial_name
  end

  # Truncate text to fit below a quad icon
  TRUNC_AT = 13
  TRUNC_TO = 10
  def truncate_for_quad(value)
    return value if value.to_s.length < TRUNC_AT
    case @settings.fetch_path(:display, :quad_truncate)
    when "b"  # Old version, used first x chars followed by ...
      value.first(TRUNC_TO) + "..."
    when "f"  # Chop off front
      "..." + value.last(TRUNC_TO)
    else      # Chop out the middle
      numchars = TRUNC_TO / 2
      value.first(numchars) + "..." + value.last(numchars)
    end
  end

  def url_for_item_quad_text(record, id, action)
    url_for(:controller => controller_for_model(record.class),
            :action     => action,
            :id         => record.id.to_s,
            :show       => id.to_s)
  end
end
