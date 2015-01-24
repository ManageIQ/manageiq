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
  #   add_nodes              -- JSON string of nodes to add to the active tree
  #   delete_node            -- key of node to be deleted from the active tree
  #   cal_date_from
  #   cal_date_to
  #   build_calendar         -- call miqBuildCalendar, true/false or Hash with
  #                             compulsory key :skip_days
  #   init_dashboard
  #   ajax_action            -- Hash of options for AJAX action to fire
  #   cell_a_view
  #   clear_gtl_list_grid
  #   right_cell_text
  #   miq_parent_id
  #   miq_parent_class
  #   miq_record_id          -- record being displayed or edited
  #   miq_widget_dd_url      -- set dashboard widget drag drop url
  #   osf_node               -- node to open, select and focus
  #   save_open_states_trees -- Array of trees to save open states for
  #   open_accord            -- accordion to open
  #   extra_js               -- array of extra javascript chunks to be written out
  #
  #   object_tree_json  --
  #   exp               --
  #
  #   active_tree       -- x_active_tree view state from controller
  #   temp              -- @temp         view state from controller
  #
  # Following options are hashes:
  #   trees_to_replace          -- trees to be replaced
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
      :trees_to_replace      => {},
      :extra_js              => [],
      :save_open_states_trees => [],
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
    # hiding dhtmlx only calls from dynatree
    unless @options[:object_tree_json].empty?
      @out << "
        if (typeof #{@options[:active_tree]} != 'undefined') {
          obj_tree.loadJSONObject(#{@options[:object_tree_json]});
          obj_tree.loadOpenStates('obj_tree');
      }\n"
    end

    # see if any miq expression vars need to be set
    unless @options[:exp].empty?
      @out << "miq_val1_type  = '#{@options[:exp][:val1_type]}';"  if @options[:exp][:val1_type]
      @out << "miq_val1_title = '#{@options[:exp][:val1_title]}';" if @options[:exp][:val1_title]
      @out << "miq_val2_type  = '#{@options[:exp][:val2_type]};"   if @options[:exp][:val2_type]
      @out << "miq_val2_title = '#{@options[:exp][:val2_title]}';" if @options[:exp][:val2_title]
    end

    # Turn off form buttons when replacing explorer right cell
    @out << javascript_for_miq_button_visibility(false).html_safe

    @out << "cfme_delete_dynatree_cookies('#{@options[:clear_tree_cookies]}')" if @options[:clear_tree_cookies]

    @out << "dhxAccord.openItem('#{@options[:open_accord]}');" unless @options[:open_accord].to_s.empty?

    @options[:trees_to_replace].each { |tree, opts| @out << replace_tree(tree,opts) }

    if @options[:remove_nodes]
      @out << "cfmeRemoveNodeChildren('#{@options[:active_tree]}',
                                      '#{@options[:add_nodes][:key]}'
      );\n"
    end

    if @options[:add_nodes]
      @out << "
        if (typeof #{@options[:active_tree]} == 'undefined') {
          cfmeAddNodeChildren('#{@options[:active_tree]}',
                              '#{@options[:add_nodes][:key]}',
                              '#{@options[:osf_node]}',
                              #{@options[:add_nodes][:children].to_json.html_safe}
          );
        } else {
          #{@options[:active_tree]}.loadJSONObject(#{@options[:add_nodes].to_json.html_safe});
        }\n"
    end

    if @options[:delete_node]
      # using dynatree if dhtmlxtree object is undefined
      @out << "
      if (typeof #{@options[:active_tree]} == 'undefined') {
        var del_node = $j('##{@options[:active_tree]}box').dynatree('getTree').getNodeByKey('#{@options[:delete_node]}');
        del_node.remove();
      } else {
        #{@options[:active_tree]}.deleteItem('#{@options[:delete_node]}');
      }\n"
    end

    @out << "miq_widget_dd_url = '#{@options[:miq_widget_dd_url]}';" if @options[:miq_widget_dd_url]

    # Always set 'def' view in left cell as active in case it was changed to show compare/drift sections
    @out << "if ($j('#custom_left_cell_div')) dhxLayout.cells('a').view('def').setActive();"

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

    @out << "if (typeof gtl_list_grid != 'undefined') gtl_list_grid = undefined;" if @options[:clear_gtl_list_grid]

    @options[:set_visible_elements].each do |el, visible|
      @out << set_element_visible(el, visible)
    end

    @options[:expand_collapse_cells].each do |cell, e_c|
      @out << "dhxLayoutB.cells('#{cell}').#{e_c}();"
    end

    # Scroll to top of main div
    @out << "$j('#main_div').scrollTop(0);"

    @out << "dhxLayoutB.cells('b').setText('#{escape_javascript(ERB::Util::h(@options[:right_cell_text]))}');" if @options[:right_cell_text]

    # Reload toolbars
    @options[:reload_toolbars].each do |tb, opts|
      @out << javascript_for_toolbar_reload("#{tb}_tb", opts[:buttons], opts[:xml]).html_safe
    end

    # reset miq_record_id, else it remembers prev id and sends it when add is pressed from list view
    [:miq_record_id, :miq_parent_id, :miq_parent_class].each { |variable| @out << set_or_undef(variable) }

    # Open, select, and focus node in current tree
    #   using dynatree if dhtmlxtree object is undefined
    unless @options[:osf_node].empty?
      @out << "
        if (typeof #{@options[:active_tree]} == 'undefined') {
          cfmeDynatree_activateNodeSilently('#{@options[:active_tree]}', '#{@options[:osf_node]}');
        } else {
          #{@options[:active_tree]}.openItem(  '#{@options[:osf_node]}');
          #{@options[:active_tree]}.selectItem('#{@options[:osf_node]}', false);
          #{@options[:active_tree]}.focusItem( '#{@options[:osf_node]}');
        }"
    end

    @options[:lock_unlock_trees].each { |tree, lock| @out << tree_lock(tree, lock) }

    # Skip if dynatree (dhxmlttree object undefined) and use dt persist
    @options[:save_open_states_trees].each do |tree|
      tree_str = tree.to_s
      @out << "
        if (typeof #{tree_str} != 'undefined')
            #{tree_str}.saveOpenStates('#{tree_str}','path=/');"
    end

    @out << @options[:extra_js].join("\n")

    # Position and show or hide the clear_search link
    @out << "
    $j('.dhtmlxInfoBarLabel:visible').append($j('#clear_search')[0]);
    $j('#clear_search').#{clear_search_show_or_hide}();
    miqResizeTaskbarCell();"

    @out << set_spinner_off
  end

  def build_calendar
    out = []
    if Hash === @options[:build_calendar]
      calendar_options = @options[:build_calendar]
      out << "miq_cal_dateFrom = #{format_cal_date(calendar_options[:date_from])};" if calendar_options.key?(:date_from)
      out << "miq_cal_dateTo   = #{format_cal_date(calendar_options[:date_to])};"   if calendar_options.key?(:date_to)

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
    @options[variable] ? "#{variable} = '#{@options[variable]}';" : "#{variable} = undefined;"
  end

  # Replace a tree using opts hash :new_node and :load_states keys
  # opts
  #     :new_node     --
  #     :root_id      --
  #     :load_states  --
  #
  def replace_tree(tree, opts)
    tree_str = tree.to_s

    out = []
    out << 'var sel_node = ' +
      (opts[:new_node] ? "'#{opts[:new_node]}';" : "#{tree_str}_tree.getSelectedItemId();")

    out << "var root_id = '#{(opts[:root_id] || 'root')}';"

    raise "replace_tree, empty tree data for tree '#{tree_str}'" unless @options[:temp].key?((tree_str+'_tree').to_sym)
    temp_tree = @options[:temp][(tree_str+'_tree').to_sym].to_s.html_safe

    out << "#{tree_str}_tree.deleteChildItems(0);" <<
            "#{tree_str}_tree.loadJSONObject(#{temp_tree});"

    out << "#{tree_str}_tree.loadOpenStates('#{tree_str}_tree');" if opts[:load_states]

    out << "#{tree_str}_tree.setItemCloseable(root_id,0);" <<
            "#{tree_str}_tree.showItemSign(root_id,false);"

    if opts[:clear_selection]
      out << "#{tree_str}_tree.clearSelection();"
    else
      out << "#{tree_str}_tree.selectItem(sel_node);" <<
             "#{tree_str}_tree.openItem(sel_node);"
    end
    out.join("\n")
  end

  # Replaces an element (div) using options :partial and :locals
  # options
  #     :locals   --- FIXME
  #     :partial  --- FIXME
  def replace_partial(element, content)
    replace_or_update_partial('replace', element, content)
  end

  def update_partial(element, content)
    replace_or_update_partial('update', element, content)
  end

  def replace_or_update_partial(method, element, content)
    "Element.#{method}('#{element}','#{escape_javascript(content)}');"
  end

  private
  def format_cal_date(value)
    value.nil? ?  'undefined' : "new Date(#{value})"
  end
end
