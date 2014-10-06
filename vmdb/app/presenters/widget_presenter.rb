class WidgetPresenter
  include ApplicationHelper
  include ActionView::Helpers::UrlHelper
  def initialize(view, session, sb, widget)
    @view = view
    @session = session
    @sb = sb
    @widget = widget
  end

  extend Forwardable
  delegate [:session, :url_for, :initiate_wait_for_task, :session_init,
            :session_reset, :get_vmdb_config, :start_url_for_user] => :@controller

  def render_widget_buttons
    [if @view.role_allows(:feature => "dashboard_add")
       button_close
     end,
     button_minmax,
     if ["report", "chart"].include?(@widget.content_type) &&
        !@widget.contents_for_user(@session[:userid]).blank?
       button_fullscreen +
       button_pdf
     end,
     if ["chart"].include?(@widget.content_type) &&
        !@widget.contents_for_user(@session[:userid]).blank?
       button_zoom
     end].join("").html_safe
  end

  def render_widget_layout
    # TODO call in partials
  end

  private

  def button_fullscreen
    if @widget.content_type == "chart"
      @view.link_to("",
              {:action => "report_only",
               :type   => "hybrid",
               :rr_id  => @widget.contents_for_user(@session[:userid]).miq_report_result_id},
              :id                => "w_#{@widget.id}_fullscreen",
              :class             => "fullscreenbox",
              :title             => "Open the chart and full report in a new window",
              "data-miq_confirm" => "This will show the chart and the entire report" \
                                    "(all rows) in your browser. Do you want to proceed?",
              :onclick           => "return miqClickAndPop(this);")
    else
      @view.link_to("",
              {:action => "report_only",
               :type   => "tabular",
               :rr_id  => @widget.contents_for_user(@session[:userid]).miq_report_result_id},
              :id                => "w_#{@widget.id}_fullscreen",
              :class             => "fullscreenbox",
              :title             => "Open the full report in a new window",
              "data-miq_confirm" => "his will show the entire report (all rows) in your browser." \
                                    "Do you want to proceed?",
              :onclick           => "return miqClickAndPop(this);")
    end
  end

  def button_close
    unless @sb[:dashboards][@sb[:active_db]][:locked]
      @view.link_to("",
              {:controller => "dashboard",
               :action     => "widget_close",
               :widget     => @widget.id},
              :id                  => "w_#{@widget.id}_close",
              :title               => "Remove from Dashboard",
              :remote              => true,
              :confirm             => "Are you sure you want to remove '#{@widget.title}'" \
                                      "from the Dashboard?",
              'data-miq_sparkle_on'=> true,
              :class               => "delbox")
    end
  end

  def button_minmax
    unless @sb[:dashboards][@sb[:active_db]][:minimized].include?(@widget.id)
      @view.link_to("",
              {:controller => "dashboard",
               :action     => "widget_toggle_minmax",
               :widget     => "#{@widget.id}"},
              :id     => "w_#{@widget.id}_minmax",
              :title  => "Minimize",
              :remote => true,
              :class  => "minbox")
    else
      @view.link_to("",
              {:controller => "dashboard",
               :action     => "widget_toggle_minmax",
               :widget     => "#{@widget.id}"},
              :id     => "w_#{@widget.id}_minmax",
              :title  => "Restore",
              :remote => true,
              :class  => "maxbox")
    end
  end

  def button_pdf
    if PdfGenerator.available? && %w(report chart).include?(@widget.content_type)
      @view.link_to("",
              {:action => "widget_to_pdf",
               :rr_id  => @widget.contents_for_user(@session[:userid]).miq_report_result_id},
              :id    => "w_#{@widget.id}_pdf",
              :class => "pdfbox",
              :title => "Download the full report (all rows) as a PDF file")
    end
  end

  def button_zoom
    @view.link_to("",
            {:controller => "dashboard",
             :action     => "widget_zoom",
             :widget     => @widget.id},
            :id                   => "w_#{@widget.id}_zoom",
            :title                => "Zoom in on this chart",
            "data-miq_sparkle_on" => true,
            :remote               => true,
            :class                => "zoombox")
  end
end
