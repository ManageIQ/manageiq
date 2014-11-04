module JsHelper
  def set_element_visible(element, status)
    status ? javascript_show_if_exists(j_str(element)) : javascript_hide_if_exists(j_str(element))
  end

  # replacement for app/views/shared/ajax/_spinner_control.js.erb
  # Turn spinner off
  def set_spinner_off
    'miqSparkleOff();'
  end

  # replacement for app/views/shared/ajax/_tree_lock_unlock.js.erb
  def tree_lock(tree_var, lock = true)
    bool_str = (!!lock).to_s
    element = "#{tree_var}_div"
    "
      $j('##{tree_var}box').dynatree('#{lock ? 'disable' : 'enable'}');
      #{javascript_dim(element, bool_str)}
    "
  end

  # options:
  #     :legend --- FIXME: fill in docs
  #     :title  ---
  def update_element(element, options)
    if options[:legend]
      "Element.update('#{element}', '#{escape_javascript(options[:legend])}');"
    elsif options[:title]
      "Element.update('#{element}').title = '#{options[:title]}';"
    else
       ''
    end
  end

  # safe variant of j/escape_javascript that calls .to_s to work with non-string values
  def j_str(value)
    j(value.to_s)
  end

  def javascript_focus(element)
    "$j('##{element}').focus();"
  end

  def javascript_focus_if_exists(element)
    "if ($j('##{element}').length) #{javascript_focus(element)}"
  end

  def javascript_highlight(element, status)
    "miqHighlight('##{element}', #{status});"
  end

  def javascript_dim(element, status)
    "miqDimDiv('##{element}', #{status});"
  end

  def javascript_add_class(element, cls)
    "$j('##{element}').addClass('#{cls}');"
  end

  def javascript_del_class(element, cls)
    "$j('##{element}').removeClass('#{cls}');"
  end

  def javascript_show(element)
    "$j('\##{element}').show();"
  end

  def javascript_hide(element)
    "$j('\##{element}').hide();"
  end

  def javascript_show_if_exists(element)
    "if ($j('\##{element}').length) #{javascript_show(element)}"
  end

  def javascript_hide_if_exists(element)
    "if ($j('\##{element}').length) #{javascript_hide(element)}"
  end
end
