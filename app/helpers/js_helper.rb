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
      $('##{j_str(tree_var)}box').dynatree('#{lock ? 'disable' : 'enable'}');
      #{javascript_dim(element, bool_str)}
    ".html_safe
  end

  # safe variant of j/escape_javascript that calls .to_s to work with non-string values
  def j_str(value)
    j(value.to_s)
  end

  def javascript_focus(element)
    "$('##{j_str(element)}').focus();".html_safe
  end

  def javascript_prepend_span(element, cls)
    "$('##{j_str(element)}').prepend('#{content_tag(:span, nil, :class => cls)}');".html_safe
  end

  def javascript_highlight(element, status)
    "miqHighlight('##{j_str(element)}', #{j_str(status)});".html_safe
  end

  def javascript_dim(element, status)
    "miqDimDiv('##{j_str(element)}', #{j_str(status)});".html_safe
  end

  def javascript_disable_field(element)
    "$('##{j_str(element)}').prop('disabled', true);".html_safe
  end

  def javascript_enable_field(element)
    "$('##{j_str(element)}').prop('disabled', false);".html_safe
  end

  def javascript_show(element)
    "$('##{j_str(element)}').show();".html_safe
  end

  def javascript_hide(element)
    "$('##{j_str(element)}').hide();".html_safe
  end

  def javascript_show_if_exists(element)
    "if (miqDomElementExists('#{j_str(element)}')) #{javascript_show(element)}".html_safe
  end

  def javascript_hide_if_exists(element)
    "if (miqDomElementExists('#{j_str(element)}')) #{javascript_hide(element)}".html_safe
  end

  def jquery_pulsate_element(element)
    "$('##{element}').fadeIn().fadeOut().fadeIn().fadeOut().fadeIn().fadeOut().fadeIn().fadeOut().fadeIn().fadeOut().fadeIn();".html_safe
  end

  def partial_replace(from, partial, locals)
    "$(\"##{h(from)}\").replaceWith(\"#{escape_javascript(render(:partial => partial, :locals => locals))}\");".html_safe
  end

  def javascript_checked(element)
    "if ($('##{j_str(element)}').prop('type') == 'checkbox') {$('##{j_str(element)}').prop('checked', 'checked');}"
      .html_safe
  end

  def javascript_unchecked(element)
    "if ($('##{j_str(element)}').prop('type') == 'checkbox') {$('##{j_str(element)}').prop('checked', false);}"
      .html_safe
  end

  def javascript_update_element(element, content)
    "$('##{element}').html('#{escape_javascript(content)}');"
  end

  def js_build_calendar(options = {})
    skip_days = options[:skip_days].nil? ? 'undefined' : options[:skip_days].to_a.to_json

    <<EOD
ManageIQ.calendar.calDateFrom = #{js_format_date(options[:date_from])};
ManageIQ.calendar.calDateTo = #{js_format_date(options[:date_to])};
ManageIQ.calendar.calSkipDays = #{skip_days};
miqBuildCalendar();
EOD
  end

  def javascript_prologue
    'throw "error";'
  end

  def js_format_date(value)
    value.nil? ? 'undefined' : "new Date('#{value.iso8601}')"
  end
end
