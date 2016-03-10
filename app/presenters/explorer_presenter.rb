class ExplorerPresenter
  # FIXME: temporary solution, until we clean up more...
  include ApplicationHelper
  include JsHelper
  include ActionView::Helpers::JavaScriptHelper

  include ToolbarHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Context

  attr_reader :options

  # Renders JS to replace the contents of an explorer view as directed by the controller

  # This presenter supports these options:
  #   FIXME: fill in missing doc
  #
  #   add_nodes                        -- JSON string of nodes to add to the active tree
  #   delete_node                      -- key of node to be deleted from the active tree
  #   build_calendar                   -- call miqBuildCalendar, true/false or Hash (:date_from, :date_to, :skip_days)
  #   init_dashboard
  #   ajax_action                      -- Hash of options for AJAX action to fire
  #   clear_gtl_list_grid              -- Clear ManageIQ.grids.gtl_list_grid
  #   right_cell_text
  #   ManageIQ.record.parentId
  #   ManageIQ.record.parentClass
  #   ManageIQ.record.recordId         -- record being displayed or edited
  #   ManageIQ.widget.dashboardUrl     -- set dashboard widget drag drop url
  #   osf_node                         -- node to open, select and focus
  #   open_accord                      -- accordion to open
  #   extra_js                         -- array of extra javascript chunks to be written out
  #
  #   object_tree_json            --
  #   exp                         --
  #
  #   active_tree                 -- x_active_tree view state from controller
  #
  # Following options are hashes:
  #   lock_unlock_trees         -- trees to lock/unlock
  #   update_partials           -- partials to update contents
  #   replace_partials          -- partials to replace (also wrapping tag)
  #   element_updates           -- do we need all 3 of the above?
  #   set_visible_elements      -- elements to cal 'set_visible' on
  #   reload_toolbars
  #

  def initialize(options = {})
    @options = HashWithIndifferentAccess.new(
      :lock_unlock_trees    => {},
      :set_visible_elements => {},
      :update_partials      => {},
      :element_updates      => {},
      :replace_partials     => {},
      :reload_toolbars      => {},
      :extra_js             => [],
      :object_tree_json     => '',
      :exp                  => {},
      :osf_node             => '',
      :show_miq_buttons     => false,
      :load_chart           => nil
    ).update(options)
  end

  def load_chart(chart_data)
    @options[:load_chart] = chart_data
  end

  def show_miq_buttons(show = true)
    @options[show_miq_buttons] = show
  end

  def set_visibility(value, *elements)
    elements.each { |el| @options[:set_visible_elements][el] = value }
    self
  end

  def hide(*elements)
    set_visibility(false, *elements)
  end

  def show(*elements)
    set_visibility(true, *elements)
  end

  def reload_toolbars(toolbars)
    toolbars.each_pair do |div_name, toolbar_data|
      @options[:reload_toolbars][div_name] = toolbar_data
    end
    self
  end

  def replace(div_name, content)
    @options[:replace_partials][div_name] = content
    self
  end

  def update(div_name, content)
    @options[:update_partials][div_name] = content
    self
  end

  def []=(key, value)
    @options[key] = value
  end

  def [](key)
    @options[key]
  end

  def to_html
    @out = []
    process
    @out.join("\n")
  end

  private

  def process
    # see if any miq expression vars need to be set
    unless @options[:exp].empty?
      @out << "ManageIQ.expEditor.first.type = '#{@options[:exp][:val1_type]}';"  if @options[:exp][:val1_type]
      @out << "ManageIQ.expEditor.first.title = '#{@options[:exp][:val1_title]}';" if @options[:exp][:val1_title]
      @out << "ManageIQ.expEditor.second.type  = '#{@options[:exp][:val2_type]};"   if @options[:exp][:val2_type]
      @out << "ManageIQ.expEditor.second.title = '#{@options[:exp][:val2_title]}';" if @options[:exp][:val2_title]
    end

    # Turn off form buttons when replacing explorer right cell
    @out << javascript_for_miq_button_visibility(@options[:show_miq_buttons]).html_safe

    @out << "miqDeleteDynatreeCookies('#{@options[:clear_tree_cookies]}')" if @options[:clear_tree_cookies]

    # Open an accordion inside an other AJAX call
    unless @options[:open_accord].to_s.empty?
      @out << "miqAccordionSwap('#accordion .panel-collapse.collapse.in', '##{j(@options[:open_accord])}_accord');"
    end

    if @options[:remove_nodes]
      @out << "miqRemoveNodeChildren('#{@options[:active_tree]}',
                                     '#{@options[:add_nodes][:key]}'
      );\n"
    end

    if @options[:add_nodes]
      @out << "
        miqAddNodeChildren('#{@options[:active_tree]}',
                           '#{@options[:add_nodes][:key]}',
                           '#{@options[:osf_node]}',
                            #{@options[:add_nodes][:children].to_json.html_safe}
        );
      \n"
    end

    if @options[:delete_node]
      @out << "
        var del_node = $('##{@options[:active_tree]}box').dynatree('getTree').getNodeByKey('#{@options[:delete_node]}');
        del_node.remove();
        \n"
    end

    @out << "ManageIQ.widget.dashboardUrl = '#{@options[:miq_widget_dd_url]}';" if @options[:miq_widget_dd_url]

    # Always set 'def' view in left cell as active in case it was changed to show compare/drift sections
    @out << "var show_clear_search = undefined"
    @out << "
      if ($('#advsearchModal').hasClass('modal fade in')){
        $('#advsearchModal').modal('hide');}"

    # Update elements in the DOM with rendered partials
    @options[:update_partials].each { |element, content| @out << update_partial(element, content) }

    # Update element in the DOM with given options
    @options[:element_updates].each { |element, options| @out << update_element(element, options) }

    # Replace elements in the DOM with rendered partials
    @options[:replace_partials].each { |element, content| @out << replace_partial(element, content) }

    @out << build_calendar if @options[:build_calendar]

    @out << 'miqInitDashboardCols();' if @options[:init_dashboard]

    @out << ajax_action(@options[:ajax_action]) if @options[:ajax_action]

    @out << "ManageIQ.grids.gtl_list_grid = undefined;" if @options[:clear_gtl_list_grid]

    @options[:set_visible_elements].each do |el, visible|
      @out << set_element_visible(el, visible)
    end

    # Scroll to top of main div
    @out << "$('#main_div').scrollTop(0);"

    @out << "$('h1#explorer_title > span#explorer_title_text').html('#{j ERB::Util.h(URI.unescape(@options[:right_cell_text]))}');" if @options[:right_cell_text]

    # Reload toolbars
    @options[:reload_toolbars].each_pair do |div_name, toolbar|
      # we need to render even empty toolbar to actually remove the buttons
      # that might be there
      @out << javascript_pf_toolbar_reload("#{div_name}_tb", Array(toolbar)).html_safe
    end

    # reset miq_record_id, else it remembers prev id and sends it when add is pressed from list view
    [:record_id, :parent_id, :parent_class].each { |variable| @out << set_or_undef(variable.to_s) }

    # Open, select, and focus node in current tree
    @out << "miqDynatreeActivateNodeSilently('#{@options[:active_tree]}', '#{@options[:osf_node]}');" unless @options[:osf_node].blank?

    @options[:lock_unlock_trees].each { |tree, lock| @out << tree_lock(tree, lock) }

    @out << @options[:extra_js].join("\n")

    if @options[:load_chart]
      @out << 'ManageIQ.charts.chartData = ' + @options[:load_chart].to_json + ';'
      @out << Charting.js_load_statement(true)
    end

    @out << "$('#clear_search').#{@options[:clear_search_show_or_hide]}();" if @options[:clear_search_show_or_hide]
    # always replace content partial to adjust height of content div
    @out << "miqInitMainContent();"
    @out << "$('#quicksearchbox').modal('hide');" if @options[:hide_modal]

    # Don't turn off spinner for charts/timelines
    @out << set_spinner_off unless @options[:ajax_action]
  end

  def build_calendar
    if @options[:build_calendar].kind_of? Hash
      calendar_options = @options[:build_calendar]
    else
      calendar_options = {}
    end

    js_build_calendar(calendar_options)
  end

  # Fire an AJAX action
  def ajax_action(options)
    url = [options[:controller], options[:action], options[:record_id]].join('/')
    "miqAsyncAjax('/#{url}');"
  end

  # Set a JS variable to value from options or 'undefined'
  def set_or_undef(variable)
    if @options[variable]
      "ManageIQ.record.#{variable.camelize(:lower)} = '#{@options[variable]}';"
    else
      "ManageIQ.record.#{variable.camelize(:lower)} = null;"
    end
  end

  # Replaces an element (div) using options :partial and :locals
  # options
  #     :locals   --- FIXME
  #     :partial  --- FIXME
  def replace_partial(element, content)
    "$('##{element}').replaceWith('#{escape_javascript(content)}');"
  end

  def update_partial(element, content)
    # FIXME: replace with javascript_update_element
    "$('##{element}').html('#{escape_javascript(content)}');"
  end
end
