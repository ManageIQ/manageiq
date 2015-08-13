class ExplorerPresenter
  # FIXME: temporary solution, until we clean up more...
  include ApplicationHelper
  include JsHelper
  include ActionView::Helpers::JavaScriptHelper

  attr_reader :options

  # Renders JS to replace the contents of an explorer view as directed by the controller

  # This presenter supports these options:
  #   FIXME: fill in missing doc
  #
  #   add_nodes                        -- JSON string of nodes to add to the active tree
  #   delete_node                      -- key of node to be deleted from the active tree
  #   cal_date_from
  #   cal_date_to
  #   build_calendar                   -- call miqBuildCalendar, true/false or Hash with
  #                                       compulsory key :skip_days
  #   init_dashboard
  #   ajax_action                      -- Hash of options for AJAX action to fire
  #   cell_a_view
  #   clear_gtl_list_grid
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
  #   expand_collapse_cells     -- cells to expand/collapse
  #   reload_toolbars
  #

  def initialize(options={})
    @options = HashWithIndifferentAccess.new(
      :lock_unlock_trees     => {},
      :set_visible_elements  => {},
      :expand_collapse_cells => {},
      :update_partials       => {},
      :element_updates       => {},
      :replace_partials      => {},
      :reload_toolbars       => {},
      :extra_js              => [],
      :object_tree_json      => '',
      :exp                   => {},
      :osf_node              => ''
    ).update(options)
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

  def process
    # see if any miq expression vars need to be set
    unless @options[:exp].empty?
      @out << "ManageIQ.expEditor.first.type = '#{@options[:exp][:val1_type]}';"  if @options[:exp][:val1_type]
      @out << "ManageIQ.expEditor.first.title = '#{@options[:exp][:val1_title]}';" if @options[:exp][:val1_title]
      @out << "ManageIQ.expEditor.second.type  = '#{@options[:exp][:val2_type]};"   if @options[:exp][:val2_type]
      @out << "ManageIQ.expEditor.second.title = '#{@options[:exp][:val2_title]}';" if @options[:exp][:val2_title]
    end

    # Turn off form buttons when replacing explorer right cell
    @out << javascript_for_miq_button_visibility(false).html_safe

    @out << "cfme_delete_dynatree_cookies('#{@options[:clear_tree_cookies]}')" if @options[:clear_tree_cookies]

    @out << "dhxAccord.openItem('#{@options[:open_accord]}');" unless @options[:open_accord].to_s.empty?

    if @options[:remove_nodes]
      @out << "cfmeRemoveNodeChildren('#{@options[:active_tree]}',
                                      '#{@options[:add_nodes][:key]}'
      );\n"
    end

    if @options[:add_nodes]
      @out << "
        cfmeAddNodeChildren('#{@options[:active_tree]}',
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
    @out << "if (miqDomElementExists('custom_left_cell_div')) dhxLayout.cells('a').view('def').setActive();"
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

    @out << "dhxLayout.cells('a').view('#{@options[:cell_a_view]}').setActive();" if @options[:cell_a_view]

    @out << "ManageIQ.grids.grids['gtl_list_grid'] = undefined;" if @options[:clear_gtl_list_grid]

    @options[:set_visible_elements].each do |el, visible|
      @out << set_element_visible(el, visible)
    end

    @options[:expand_collapse_cells].each do |cell, e_c|
      @out << "dhxLayoutB.cells('#{cell}').#{e_c}();"
    end

    # Scroll to top of main div
    @out << "$('#main_div').scrollTop(0);"

    @out << "dhxLayoutB.cells('b').setText('#{escape_javascript(ERB::Util::h(@options[:right_cell_text]))}');" if @options[:right_cell_text]

    # Reload toolbars
    @options[:reload_toolbars].each do |tb, opts|
      @out << javascript_for_toolbar_reload("#{tb}_tb", opts[:buttons], opts[:xml]).html_safe
    end

    # reset miq_record_id, else it remembers prev id and sends it when add is pressed from list view
    [:record_id, :parent_id, :parent_class].each { |variable| @out << set_or_undef(variable.to_s) }

    # Open, select, and focus node in current tree
    #   using dynatree if dhtmlxtree object is undefined
    @out << "cfmeDynatree_activateNodeSilently('#{@options[:active_tree]}', '#{@options[:osf_node]}');" unless @options[:osf_node].empty?

    @options[:lock_unlock_trees].each { |tree, lock| @out << tree_lock(tree, lock) }

    @out << @options[:extra_js].join("\n")

    # Position the clear_search link
    @out << "$('.dhtmlxInfoBarLabel').filter(':visible').append($('#clear_search')[0]);
    miqResizeTaskbarCell();"

    @out << "$('#clear_search').#{@options[:clear_search_show_or_hide]}();" if @options[:clear_search_show_or_hide]

    @out << "$('#quicksearchbox').modal('hide');" if @options[:hide_modal]

    # Don't turn off spinner for charts/timelines
    @out << set_spinner_off unless @options[:ajax_action]
  end

  def build_calendar
    out = []
    if Hash === @options[:build_calendar]
      calendar_options = @options[:build_calendar]
      out << "ManageIQ.calendar.calDateFrom = #{format_cal_date(calendar_options[:date_from])};" if calendar_options.key?(:date_from)
      out << "ManageIQ.calendar.calDateTo   = #{format_cal_date(calendar_options[:date_to])};"   if calendar_options.key?(:date_to)

      if calendar_options.key?(:skip_days)
        skip_days = calendar_options[:skip_days].nil? ?
          'null' : ("'" + calendar_options[:skip_days] + "'")
        out << "miq_cal_skipDays = #{skip_days};"
      end
    end

    out << 'miqBuildCalendar();'
    out.join("\n")
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
    "$('##{element}').html('#{escape_javascript(content)}');"
  end

  private
  def format_cal_date(value)
    value.nil? ?  'undefined' : "new Date(#{value})"
  end
end
