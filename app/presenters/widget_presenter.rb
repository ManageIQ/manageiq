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
  delegate [:current_user, :url_for, :initiate_wait_for_task, :session_init,
            :session_reset, :get_vmdb_config, :start_url_for_user] => :@controller

  attr_reader :widget

  def render_partial
    @controller.render_to_string(:template => 'dashboard/_widget', :handler => [:haml],
                                 :layout => false, :locals => {:presenter => self}).html_safe
  end

  def button_fullscreen
    if @widget.content_type == "chart"
      @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-arrows-alt fa-fw') + _(" Full Screen"),
                    {:action => "report_only",
                     :type   => "hybrid",
                     :rr_id  => @widget.contents_for_user(current_user).miq_report_result_id},
                    :id                => "w_#{@widget.id}_fullscreen",
                    :title             => _("Open the chart and full report in a new window"),
                    "data-miq_confirm" => _("This will show the chart and the entire report " \
                                            "(all rows) in your browser. Do you want to proceed?"),
                    :onclick           => "return miqClickAndPop(this);")
    else
      @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-arrows-alt fa-fw') + _(" Full Screen"),
                    {:action => "report_only",
                     :type   => "tabular",
                     :rr_id  => @widget.contents_for_user(current_user).miq_report_result_id},
                    :id                => "w_#{@widget.id}_fullscreen",
                    :title             => _("Open the full report in a new window"),
                    "data-miq_confirm" => _("This will show the entire report (all rows) in your browser. " \
                                            "Do you want to proceed?"),
                    :onclick           => "return miqClickAndPop(this);")
    end
  end

  def button_close
    unless @sb[:dashboards][@sb[:active_db]][:locked]
      @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-times fa-fw') + _(" Remove Widget"),
                    {:controller => "dashboard",
                     :action     => "widget_close",
                     :widget     => @widget.id},
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
    @view.link_to(@view.content_tag(:span, '',
                                    :class  => "fa fa-caret-square-o-#{minimized ? 'down' : 'up'} fa-fw") + title,
                  {:controller => "dashboard",
                   :action     => "widget_toggle_minmax",
                   :widget     => @widget.id},
                  :id           => "w_#{@widget.id}_minmax",
                  :title        => title,
                  :remote       => true,
                  'data-method' => :post)
  end


  def button_pdf
    if PdfGenerator.available? && %w(report chart).include?(@widget.content_type)
      @view.link_to(@view.content_tag(:span, '', :class => 'fa fa-file-pdf-o fa-fw') + _(" Download PDF"),
                    {:action => "widget_to_pdf",
                     :rr_id  => @widget.contents_for_user(current_user).miq_report_result_id},
                    :id    => "w_#{@widget.id}_pdf",
                    :title => _("Download the full report (all rows) as a PDF file"))
    end
  end

  def button_zoom
    @view.link_to(@view.content_tag(:span, '', :class => "fa fa-plus fa-fw") + _(" Zoom in"),
                  {:controller => "dashboard",
                   :action     => "widget_zoom",
                   :widget     => @widget.id},
                  :id                   => "w_#{@widget.id}_zoom",
                  :title                => _("Zoom in on this chart"),
                  "data-miq_sparkle_on" => true,
                  :remote               => true,
                  'data-method'         => :post)
  end

  def self.chart_data
    @@chart_data ||= []
  end
end
