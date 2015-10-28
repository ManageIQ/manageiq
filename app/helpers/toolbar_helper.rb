module ToolbarHelper
  # Public interface

  # Render a list of buttons (toolbar) to html
  #
  # Called directly when updating toolbars in an existing page.
  #
  def buttons_to_html(buttons)
    Array(buttons).collect do |button|
      toolbar_top_button(button)
    end.join('').html_safe
  end

  # Request that a toolbar is rendered.
  #
  #   * div_id        -- toolbar div DOM id
  #   * toolbar_name  -- toolbar name (presently means name of the yaml file
  #                      with tb definition)
  #
  # We should remove this method as we refactor the partials that call it.
  #
  def defered_toolbar_render(div_id, toolbar_name)
    div_id ||= 'center_tb'
    @toolbars[div_id] = toolbar_name
  end

  # Actually render the toolbars requested by 'defered_toolbar_render'
  #
  # We should call rendering directly once when remove 'defered_toolbar_render'.
  #
  def render_toolbars
    @toolbars.collect do |div_id, toolbar_name|
      content_tag(:div, :id => div_id, :class => 'form-group') do # form-group aroung each toolbar
        buttons = toolbar_name ? build_toolbar(toolbar_name) : nil
        buttons_to_html(buttons)
      end
    end.join('').html_safe
  end

  # Internal stuff to generate html markup

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
      toolbar_button_separator(props)
    else
      raise 'Invalid top button type.'
    end
  end

  # Render image to go on a toolbar button
  #
  def toolbar_image(props)
    tag(:img,
        :src            => t = "/images/toolbars/#{props['img']}",
        'data-enabled'  => t,
        'data-disabled' => "/images/toolbars/#{props['imgdis']}")
  end

  # Render drop-down top button
  #
  def toolbar_top_button_select(props)
    content_tag(:div, :class => 'btn-group dropdown') do
      cls = props[:hidden] ? 'hidden ' : ''
      cls += 'disabled ' if props['enabled'].to_s == 'false'
      out = []
      out << content_tag(:button,
                         prepare_tag_keys(props).update(
                           :type         => "button",
                           :class        => "#{cls}btn btn-default dropdown-toggle",
                           'data-toggle' => "dropdown",
                         )) do
        (toolbar_image(props) +
          props['text'].to_s + "&nbsp;".html_safe +
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
    content_tag(:button, prepare_tag_keys(props).update(
                           :type  => "button",
                           :class => "#{cls}btn btn-default")) do
      (toolbar_image(props) +
        props['text'].to_s + "&nbsp;".html_safe).html_safe
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
  def toolbar_button_separator(_props)
    content_tag(:div, '', :class => :divider, :role => "presentation")
  end

  # Render normal push child button
  #
  def toolbar_button_normal(props)
    hidden = props[:hidden]
    cls = props['enabled'].to_s == 'false' ? 'disabled ' : ''
    content_tag(:li, :class => cls + (hidden ? 'hidden' : '')) do
      content_tag(:a, prepare_tag_keys(props).update(:href => '#')) do
        (toolbar_image(props) + props['text'].to_s.html_safe)
      end
    end
  end

  # Get keys and values from tb button definition that map 1:1 to data-*
  # attributes in html
  #
  def data_hash_keys(props)
    %i(pressed popup console_url prompt explorer confirm onwhen url_parms url).each_with_object({}) do |key, h|
      h["data-#{key}"] = props[key] if props.key?(key)
    end
  end

  # Calculate common html tag keys and values from toolbar button definition
  #
  def prepare_tag_keys(props)
    h = data_hash_keys(props)
    h['name']       = props[:name] if props.key?(:name)
    h['title']      = props['title']
    h['data-click'] = props['id']
    h
  end
end
