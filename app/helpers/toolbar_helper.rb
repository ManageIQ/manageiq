module ToolbarHelper
  # Public interface

  # Render a list of buttons (toolbar) to html
  #
  # Called directly when updating toolbars in an existing page.
  #
  def buttons_to_html(buttons_in)
    groups = split_to_groups(Array(buttons_in))

    groups.collect do |buttons|
      buttons = Array(buttons)

      # exceptional behavior for view toolbar view mode buttons
      view_buttons = buttons.first.present? &&
                     buttons.first[:name] =~ /^view_/

      cls = view_buttons ? 'toolbar-pf-view-selector ' : ''
      cls += 'hidden ' unless buttons.find { |button| !button[:hidden] }
      content_tag(:div, :class => "#{cls} form-group") do # form-group aroung each toolbar section
        if view_buttons
          view_mode_buttons(buttons)
        else
          normal_toolbar_buttons(buttons)
        end
      end
    end.join('').html_safe
  end

  # Render a set of whole toolbars
  #
  def render_toolbars(toolbars)
    toolbars.collect do |div_id, toolbar_name|
      content_tag(:div, :id => div_id) do # div for each toolbar
        buttons = toolbar_name ? build_toolbar(toolbar_name) : nil
        buttons_to_html(buttons)
      end
    end.join('').html_safe
  end

  # Internal stuff to generate html markup

  # Render a group of view toolbar buttons
  #
  def view_mode_buttons(buttons)
    content_tag(:ul, :class => 'list-inline') do
      buttons.collect do |button|
        toolbar_button_normal(button, true)
      end.join('').html_safe
    end
  end

  # Render a group of normal toolbar buttons
  #
  def normal_toolbar_buttons(buttons)
    buttons.collect do |button|
      toolbar_top_button(button)
    end.join('').html_safe
  end

  # Split buttons to groups at separators
  #
  def split_to_groups(buttons)
    buttons.slice_before do |props|
      props['type'] == 'separator' ||
        props[:name] == 'download_choice' # exceptional behavior for view toolbar download drop down
    end.to_a
  end

  # Render toolbar top button.
  #
  def toolbar_top_button(props)
    case props['type']
    when 'buttonSelect'
      toolbar_top_button_select(props)
    when 'button'
      toolbar_top_button_normal(props)
    when 'buttonTwoState'
      toolbar_top_button_normal(props)
    when 'separator'
    else
      raise 'Invalid top button type.'
    end
  end

  # Render image/icon to go on a toolbar button
  #
  def toolbar_image(props)
    if props[:icon].present?
      content_tag(:i, '', :class => props[:icon], :style => props['text'].present? ? 'margin-right: 5px;' : '')
    else
      img = ActionController::Base.helpers.image_path("toolbars/#{props['img']}")
      imgdis = ActionController::Base.helpers.image_path("toolbars/#{props['imgdis']}")
      tag(:img, :src => t = "#{img}", 'data-enabled' => t, 'data-disabled' => "#{imgdis}")
    end
  end

  # Render drop-down top button
  #
  def toolbar_top_button_select(props)
    cls = props[:hidden] ? 'hidden ' : ''
    content_tag(:div, :class => "#{cls}btn-group dropdown") do
      cls += 'disabled ' if props['enabled'].to_s == 'false'
      out = []
      out << content_tag(:button,
                         prepare_tag_keys(props).update(
                           :type         => "button",
                           :class        => "#{cls}btn btn-default dropdown-toggle",
                           'data-toggle' => "dropdown",
                         )) do
        (toolbar_image(props) +
          _(props['text'].to_s) + "&nbsp;".html_safe +
          content_tag(:span, '', :class => "caret")).html_safe
      end
      out << content_tag(:ul, :class => 'dropdown-menu') do
        Array(props[:items]).collect do |button|
          toolbar_button(button)
        end.join('').html_safe
      end
      out.join('').html_safe
    end
  end

  # Render normal push top button
  #
  def toolbar_top_button_normal(props)
    cls = props[:hidden] ? 'hidden ' : ''
    cls += 'active ' if props['selected'] # for buttonTwoState only
    cls += 'disabled ' if props['enabled'] == 'false'
    content_tag(:button, prepare_tag_keys(props).update(
                           :type  => "button",
                           :class => "#{cls}btn btn-default")) do
      (toolbar_image(props) +
        _(props['text'].to_s) + "&nbsp;".html_safe).html_safe
    end
  end

  # Render child button (in the drop-down)
  #
  def toolbar_button(props)
    case props['type']
    when 'button'
      toolbar_button_normal(props)
    when 'separator'
      toolbar_button_separator(props)
    else
      raise 'Invalid button type.'
    end
  end

  # Render separator in the drop down
  #
  def toolbar_button_separator(props)
    cls = props[:hidden] ? ' hidden' : ''
    content_tag(:div, '', :class => "divider #{cls}", :role => "presentation")
  end

  # Render normal push child button
  #
  def toolbar_button_normal(props, view_button = false)
    hidden = props[:hidden]
    cls = if view_button
            props['enabled'].to_s == 'false' ? 'active ' : ''
          else
            props['enabled'].to_s == 'false' ? 'disabled ' : ''
          end
    content_tag(:li, :class => cls + (hidden ? 'hidden' : '')) do
      content_tag(:a, prepare_tag_keys(props).update(:href => '#')) do
        (toolbar_image(props) + _(props['text'].to_s).html_safe)
      end
    end
  end

  # Get keys and values from tb button definition that map 1:1 to data-*
  # attributes in html
  #
  def data_hash_keys(props)
    %i(pressed popup window_url prompt explorer onwhen url_parms url).each_with_object({}) do |key, h|
      h["data-#{key}"] = props[key] if props[key].present?
    end
  end

  # Calculate common html tag keys and values from toolbar button definition
  #
  def prepare_tag_keys(props)
    h = data_hash_keys(props)
    h.update('title'      => _(props['title']),
             'data-click' => props['id'])
    h['name']         = props[:name] if props.key?(:name)
    h['data-confirm-tb'] = _(props[:confirm]) if props.key?(:confirm)
    h
  end
end
