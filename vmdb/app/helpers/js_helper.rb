module JsHelper
  def set_element_visible(element, status)
    status ? javascript_show_if_exists(element) : javascript_hide_if_exists(element)
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
      $j('##{j_str(tree_var)}box').dynatree('#{lock ? 'disable' : 'enable'}');
      #{javascript_dim(element, bool_str)}
    ".html_safe
  end

  # options:
  #     :legend --- FIXME: fill in docs
  #     :title  ---
  def update_element(element, options)
    if options[:legend]
      "$j('##{element}').html('#{escape_javascript(options[:legend]).html_safe}');"
    elsif options[:title]
      "$j('##{element}').html('#{escape_javascript(options[:title]).html_safe}');"
     # "Element.update('#{element}').title = '#{options[:title]}';"
    else
       ''
    end
  end

  # safe variant of j/escape_javascript that calls .to_s to work with non-string values
  def j_str(value)
    j(value.to_s)
  end

  def javascript_focus(element)
    "$j('##{j_str(element)}').focus();".html_safe
  end

  def javascript_focus_if_exists(element)
    "if ($j('##{j_str(element)}').length) #{javascript_focus(element)}".html_safe
  end

  def javascript_highlight(element, status)
    "miqHighlight('##{j_str(element)}', #{j_str(status)});".html_safe
  end

  def javascript_dim(element, status)
    "miqDimDiv('##{j_str(element)}', #{j_str(status)});".html_safe
  end

  def javascript_add_class(element, cls)
    "$j('##{j_str(element)}').addClass('#{j_str(cls)}');".html_safe
  end

  def javascript_del_class(element, cls)
    "$j('##{j_str(element)}').removeClass('#{j_str(cls)}');".html_safe
  end

  def javascript_disable_field(element)
    "$j('##{j_str(element)}').prop('disabled', true);".html_safe
  end

  def javascript_enable_field(element)
    "$j('##{j_str(element)}').prop('disabled', false);".html_safe
  end

  def javascript_show(element)
    "$j('##{j_str(element)}').show();".html_safe
  end

  def javascript_hide(element)
    "$j('##{j_str(element)}').hide();".html_safe
  end

  def javascript_show_if_exists(element)
    "if (miqDomElementExists('#{j_str(element)}')) #{javascript_show(element)}".html_safe
  end

  def javascript_hide_if_exists(element)
    "if (miqDomElementExists('#{j_str(element)}')) #{javascript_hide(element)}".html_safe
  end

  def jquery_pulsate_element(element)
    "$j('##{element}').fadeIn().fadeOut().fadeIn().fadeOut().fadeIn().fadeOut().fadeIn().fadeOut().fadeIn().fadeOut().fadeIn();".html_safe
  end

  def js_for_page_replace_html(div, partial_name, locals = {})
    "$j('##{div}').html('#{escape_javascript(render :partial => partial_name, :locals => locals).html_safe}');"
  end

  def js_for_page_replace(div, partial_name, locals = {})
    "$j('##{div}').replaceWith('#{escape_javascript(render :partial => partial_name, :locals => locals).html_safe}');"
  end
end
