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

    if options[:mode] == :text # Rendering the text link, not the quadicon
      return render(
               :partial => "layouts/quadicon/quadicon_text",
               :locals  => {
                 :db              => options[:db],
                 :truncate_length => 13,
                 :row             => options[:row],
                 :item            => item
               }
      )
    end

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

  def db_from_item(item)
    item.kind_of?(ExtManagementSystem) ? item.class.db_name : item.class.base_model.name
  end

  def partial_name_from_item(item)
    partial_name = if %w(EmsCluster ResourcePool Repository Service ServiceTemplate Storage).include?(item.class.name)
                     item.class.name.underscore
                   elsif item.kind_of?(VmOrTemplate)
                     item.class.base_model.to_s.underscore
                   elsif item.kind_of?(ManageIQ::Providers::Foreman::ConfigurationManager) || item.kind_of?(ManageIQ::Providers::AnsibleTower::ConfigurationManager)
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
    "100/vendor-#{h(item.vendor.downcase)}.png"
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
    "100/vendor-#{h(item.vmm_vendor_display.downcase)}.png"
  end
end
