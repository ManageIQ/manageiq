module ToolbarHelper
  def toolbar_top_button(props)
    case props['type']
    when 'buttonSelect'
      toolbar_top_button_select(props)
    when 'button'
      toolbar_top_button_normal(props)
    when 'buttonTwoState'
      toolbar_top_button_normal(props)  # FIXME
    else
      binding.pry
    end
  end

  def toolbar_image(props)
    tag(:img,
      :src => "/images/toolbars/#{props['img']}",
      :style => 'margin-right: 5px; width: 15px',
      'data-enabled'  => "/images/toolbars/#{props['img']}",
      'data-disabled' => "/images/toolbars/#{props['imgdis']}",
    )
  end

  def toolbar_top_button_select(props)
    content_tag(:div, :class => 'btn-group dropdown') do
      css = props[:hidden] ? 'hidden ' : ''
      out = []
      out << content_tag(:button,
                         data_hash_keys(props).update(
                           :type => "button",
                           :class        => "#{css}btn btn-default dropdown-toggle",
                           'data-toggle' => "dropdown",
                           :title        => props['title'],
                           'data-click'  => props['id']
                         )) do
               (toolbar_image(props) +
                 props['text'].to_s + "&nbsp;".html_safe +
                 content_tag(:span, '', :class => "caret")).html_safe
             end
      out << content_tag(:ul, :class => 'dropdown-menu') do
               props[:items].collect do |button|
                 toolbar_button(button)
               end.join('').html_safe
             end
      out.join('').html_safe
    end
  end

  def toolbar_top_button_normal(props)
    css = props[:hidden] ? 'hidden ' : ''
    content_tag(:button,
                data_hash_keys(props).update(
                  :type        => "#{css}button",
                  :class       => "btn btn-default",
                  :title       => props['title'],
                  'data-click' => props['id']
               )) do
      (toolbar_image(props) +
        props['text'].to_s + "&nbsp;".html_safe).html_safe
    end
  end

  def toolbar_button(props)
    case props['type']
    when 'button'
      toolbar_button_normal(props)
    when 'separator'
      toolbar_button_separator(props)
    else
      binding.pry
    end
  end

  def toolbar_button_separator(props)
    content_tag(:div, '', {:class => :divider, :role => "presentation"})
  end

  def toolbar_button_normal(props)
    binding.pry if props.key?(:onwhen)
    hidden = props[:hidden]
    content_tag(:li, :title => props['title'], :class => hidden ? 'hidden' : '') do
      content_tag(:a,
                  data_hash_keys(props).update(
                    :href        => '#',
                    'data-click' => props['id']
                  )) do
        (toolbar_image(props) + props['text']).html_safe
      end
    end
  end

  def data_hash_keys(props)
    %i(pressed popup console_url name prompt explorer confirm onwhen url_parms).each_with_object({}) do |key, h|
      h["data-#{key.to_s}"] = props[key] if props.key?(key)
    end
  end

  def defered_toolbar_render(div_id, toolbar_name)
    div_id ||= 'center_tb'
    @toolbars[div_id] = toolbar_name
  end

  def buttons_to_html(buttons)
    buttons.collect do |button|
      toolbar_top_button(button)
    end.join('').html_safe
  end

  def render_toolbars
    @toolbars.collect do |div_id, toolbar_name|
      content_tag(:div, :id => div_id, :class => 'btn-group') do  # btn-group aroung each toolbar
        _tb_buttons, _tb_xml, buttons = build_toolbar_buttons_and_xml(toolbar_name)
        buttons_to_html(buttons)
      end
    end.join('').html_safe
  end
end
