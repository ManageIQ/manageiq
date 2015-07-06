class WidgetPresenter
  include ApplicationHelper
  include ActionView::Helpers::UrlHelper

  def initialize(view, controller, widget)
    @view = view
    @controller = controller
    @widget = widget
    @sb = controller.instance_eval { @sb }
    @@chart_data ||= []
  end

  extend Forwardable
  delegate [:session, :url_for, :initiate_wait_for_task, :session_init,
            :session_reset, :get_vmdb_config, :start_url_for_user] => :@controller

  attr_reader :widget

  def render_partial
    @controller.render_to_string(:template => 'dashboard/_widget', :handler => [:haml],
                                 :layout => false, :locals => {:presenter => self}).html_safe
  end

  def button_fullscreen
    if @widget.content_type == "chart"
      @view.link_to("",
                    {:action => "report_only",
                     :type   => "hybrid",
                     :rr_id  => @widget.contents_for_user(session[:userid]).miq_report_result_id},
                    :id                => "w_#{@widget.id}_fullscreen",
                    :class             => "fullscreenbox",
                    :title             => _("Open the chart and full report in a new window"),
                    "data-miq_confirm" => _("This will show the chart and the entire report " \
                                            "(all rows) in your browser. Do you want to proceed?"),
                    :onclick           => "return miqClickAndPop(this);")
    else
      @view.link_to("",
                    {:action => "report_only",
                     :type   => "tabular",
                     :rr_id  => @widget.contents_for_user(session[:userid]).miq_report_result_id},
                    :id                => "w_#{@widget.id}_fullscreen",
                    :class             => "fullscreenbox",
                    :title             => _("Open the full report in a new window"),
                    "data-miq_confirm" => _("This will show the entire report (all rows) in your browser. " \
                                            "Do you want to proceed?"),
                    :onclick           => "return miqClickAndPop(this);")
    end
  end

  def button_close
    unless @sb[:dashboards][@sb[:active_db]][:locked]
      @view.link_to("",
                    {:controller => "dashboard",
                     :action     => "widget_close",
                     :widget     => @widget.id},
                    :id                   => "w_#{@widget.id}_close",
                    :title                => _("Remove from Dashboard"),
                    :remote               => true,
                    :confirm              => _("Are you sure you want to remove '%s'" \
                                               "from the Dashboard?") % @widget.title,
                    'data-miq_sparkle_on' => true,
                    :class                => "delbox")
    end
  end

  def button_minmax
    @view.link_to("",
                  {:controller => "dashboard",
                   :action     => "widget_toggle_minmax",
                   :widget     => @widget.id},
                  :id     => "w_#{@widget.id}_minmax",
                  :title  => @sb[:dashboards][@sb[:active_db]][:minimized].include?(@widget.id) ?
                             _("Restore") : _("Minimize"),
                  :remote => true,
                  :class  => "maxbox")
  end

  def button_pdf
    if PdfGenerator.available? && %w(report chart).include?(@widget.content_type)
      @view.link_to("",
                    {:action => "widget_to_pdf",
                     :rr_id  => @widget.contents_for_user(session[:userid]).miq_report_result_id},
                    :id    => "w_#{@widget.id}_pdf",
                    :class => "pdfbox",
                    :title => _("Download the full report (all rows) as a PDF file"))
    end
  end

  def button_zoom
    @view.link_to("",
                  {:controller => "dashboard",
                   :action     => "widget_zoom",
                   :widget     => @widget.id},
                  :id                   => "w_#{@widget.id}_zoom",
                  :title                => _("Zoom in on this chart"),
                  "data-miq_sparkle_on" => true,
                  :remote               => true,
                  :class                => "zoombox")
  end

  def self.chart_data
    @@chart_data ||= []
  end

end
