module ToolbarHelper
  def toolbar_top_button(props)
    case props['type']
    when 'buttonSelect'
      toolbar_top_button_select(props)
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
      out = []
      out << content_tag(:button, :type => "button", :class => "btn btn-default dropdown-toggle",
                                  'data-toggle' => "dropdown", :title => props['title'],
                                  'data-click' => props['id'], 'data-when' => props['onwhen']) do
               (toolbar_image(props) +
                 props['text'].to_s + "&nbsp;".html_safe +
                 tag(:span, :class => "caret")).html_safe
             end 
      out << content_tag(:ul, :class => 'dropdown-menu') do
               props[:items].collect do |button|
                 toolbar_button(button)
               end.join('').html_safe
             end
      out.join('').html_safe
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
    tag(:div, :class => :divider, :role => "presentation")
  end

  def toolbar_button_normal(button)
    #  {"id"=>"history_choice__history_2",
    #  "type"=>"button",
    #  "img"=>"history.png",
    #  "imgdis"=>"history.png",
    #  "text"=>"VM or Templates under Provider &quot;vsphere 5.5&quot;",
    #  "title"=>"Go to this item"},
    content_tag(:li, :title => button['title']) do
      content_tag(:a, :href => '#', 'data-click' => button['id'], 'data-when' => button['onwhen'] ) do
        (toolbar_image(button) +
          button['text']).html_safe
      end
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
