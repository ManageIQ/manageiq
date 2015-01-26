module JqplotHelper
  def jqplot_remote(url, opts)
    chart_id   = opts[:id] || rand(10**8)
    javascript = <<-EOJ
jQuery(document).ready(function($) {
    $.ajax({
      url:      "#{url}",
      type:     "get",
      dataType: "json",
      success:  function(chart) {
        $.jqplot('#{chart_id}', chart.data, jqplot_process_options(chart.options));
      }
    });
});
EOJ
    content_tag_for_jqplot(chart_id, opts[:width], opts[:height], javascript)
  end

  def jqplot_sample(opts)
    chart_id = opts[:id] || rand(10**8)
    content_tag_for_jqplot(chart_id, opts[:width], opts[:height], '')
  end

  def jqplot(chart_data, opts)
    chart_id   = opts[:id] || rand(10**8)
    data       = chart_data[:data].to_json
    options    = chart_data[:options].to_json
    javascript = <<-EOJ
jQuery(document).ready(function($) {
  var data    = #{data};
  var options = #{options};

  $.jqplot('#{chart_id}', data, jqplot_process_options(options));
});
EOJ
    content_tag_for_jqplot(chart_id, opts[:width], opts[:height], javascript)
  end

  private

  def content_tag_for_jqplot(chart_id, width, height, javascript)
    content_tag(
      :div, '',
      :id    => chart_id,
      :style => "width: #{width}px; height: #{height}px"
    ) + javascript_tag(javascript)
  end
end
