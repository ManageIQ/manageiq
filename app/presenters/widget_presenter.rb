class WidgetPresenter
  include ApplicationHelper
  include ActionView::Helpers::UrlHelper

  def initialize(view, controller, widget)
    @view = view
    @controller = controller
    @widget = widget
    @sb = controller.instance_eval { @sb }
  end

  extend Forwardable
  def_delegators(:@controller, :current_user, :url_for, :initiate_wait_for_task,
                 :session_init, :session_reset, :start_url_for_user)

  attr_reader :widget

  def render_partial
    @controller.render_to_string(:template => 'dashboard/_widget', :handler => [:haml],
                                 :layout => false, :locals => {:presenter => self}).html_safe
  end

  def widget_html_options(widget_content_type)
    if widget_content_type == "chart"
      {:title            => _("Open the chart and full report in a new window"),
       :data_miq_confirm => _("This will show the chart and the entire report " \
                              "(all rows) in your browser. Do you want to proceed?")}
    else
      {:title            => _("Open the full report in a new window"),
       :data_miq_confirm => _("This will show the entire report (all rows) in your browser. " \
                              "Do you want to proceed?")}
    end
  end

  def button_fullscreen
    options = {:action => "report_only",
               :type   => @widget.content_type == "chart" ? "hybrid" : "tabular",
               :rr_id  => @widget.contents_for_user(current_user).miq_report_result_id}
    html_options = widget_html_options(@widget.content_type)
    @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-arrows-alt fa-fw') + _(" Full Screen"), options,
                  :id                => "w_#{@widget.id}_fullscreen",
                  :title             => html_options[:title],
                  "data-miq_confirm" => html_options[:data_miq_confirm],
                  :onclick           => "return miqClickAndPop(this);")
  end

  def button_close
    unless @sb[:dashboards][@sb[:active_db]][:locked]
      options = {:controller => "dashboard",
                 :action     => "widget_close",
                 :widget     => @widget.id}
      @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-times fa-fw') + _(" Remove Widget"), options,
                    :id                   => "w_#{@widget.id}_close",
                    :title                => _("Remove from Dashboard"),
                    :remote               => true,
                    'data-method'         => :post,
                    :confirm              => _("Are you sure you want to remove '%{title}'" \
                                               "from the Dashboard?") % {:title => @widget.title},
                    'data-miq_sparkle_on' => true)
    end
  end

  def button_minmax
    minimized = @sb[:dashboards][@sb[:active_db]][:minimized].include?(@widget.id)
    title = minimized ? _(" Maximize") : _(" Minimize")
    options = {:controller => "dashboard",
               :action     => "widget_toggle_minmax",
               :widget     => @widget.id}
    @view.link_to(@view.content_tag(:span, '',
                                    :class  => "fa fa-caret-square-o-#{minimized ? 'down' : 'up'} fa-fw") + title,
                  options,
                  :id           => "w_#{@widget.id}_minmax",
                  :title        => title,
                  :remote       => true,
                  'data-method' => :post)
  end

  def button_pdf
    if PdfGenerator.available? && %w(report chart).include?(@widget.content_type)
      options = {:action => "widget_to_pdf",
                 :rr_id  => @widget.contents_for_user(current_user).miq_report_result_id}
      @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-file-pdf-o fa-fw') + _(" Download PDF"),
                    options,
                    :id    => "w_#{@widget.id}_pdf",
                    :title => _("Download the full report (all rows) as a PDF file"))
    end
  end

  def button_zoom
    options = {:controller => "dashboard",
               :action     => "widget_zoom",
               :widget     => @widget.id}
    @view.link_to(@view.content_tag(:span, '', :class => "fa fa-plus fa-fw") + _(" Zoom in"),
                  options,
                  :id                   => "w_#{@widget.id}_zoom",
                  :title                => _("Zoom in on this chart"),
                  "data-miq_sparkle_on" => true,
                  :remote               => true,
                  'data-method'         => :post)
  end

  def self.chart_data
    @chart_data ||= []
  end

  def self.reset_data
    @chart_data = []
  end
end
