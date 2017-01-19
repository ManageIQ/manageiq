class ExplorerPresenter
  include ApplicationHelper
  include JsHelper
  include ActionView::Helpers::JavaScriptHelper

  include ToolbarHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Context

  # Returns hash for ManageIQ.explorer that contains data needed to replace the
  # contents of an explorer view as directed by the (server side) controller.

  # This presenter supports these options:
  #
  #   add_nodes                        -- JSON string of nodes to add to the active tree
  #   delete_node                      -- key of node to be deleted from the active tree
  #   clear_search_toggle              -- show or hide 'clear search' button
  #   build_calendar                   -- call miqBuildCalendar, true/false or Hash (:date_from, :date_to, :skip_days)
  #
  #   init_dashboard                   -- call miqInitDashboardCols
  #   miq_widget_dd_url                -- url to be used in url in miqDropComplete method
  #                                       (ManageIQ.widget.dashboardUrl)
  #
  #   init_accords                     -- initialize accordion autoresize
  #   ajax_action                      -- Hash of options for AJAX action to fire
  #   clear_gtl_list_grid              -- Clear ManageIQ.grids.gtl_list_grid
  #   right_cell_text
  #
  #   :record_id    sets ManageIQ.record.recordId     -- record being displayed or edited
  #   :parent_id    sets ManageIQ.record.parentId     -- it's parent
  #   :parent_class sets ManageIQ.record.parentClass  -- and it's (parent's) class
  #
  #   osf_node                         -- node to open, select and focus
  #   open_accord                      -- accordion to open
  #   exp                              -- data for the expression editor
  #   active_tree                      -- x_active_tree view state from controller
  #
  # Following options are hashes:
  #   lock_unlock_trees         -- trees to lock/unlock
  #   update_partials           -- partials to update contents
  #   replace_partials          -- partials to replace (also wrapping tag)
  #   element_updates           -- update DOM element content or title FIXME: content can be
  #                                replaced with update_partials
  #   set_visible_elements      -- elements to cal 'set_visible' on
  #   reload_toolbars           -- toolbars to reload and their content
  #

  def self.right_cell(args = {})
    new(args.update(:mode => 'right_cell'))
  end

  def self.flash(args = {})
    new(args.update(:mode => 'flash'))
  end

  def self.main_div(args = {})
    new(args.update(:mode => 'main_div'))
  end

  def self.buttons(show)
    new(:mode => 'buttons', :show_miq_buttons => show)
  end

  def initialize(options = {})
    @options = {
      :lock_unlock_trees    => {},
      :set_visible_elements => {},
      :update_partials      => {},
      :element_updates      => {},
      :replace_partials     => {},
      :reload_toolbars      => {},
      :exp                  => {},
      :osf_node             => '',
      :show_miq_buttons     => false,
      :load_chart           => nil,
      :open_window          => nil,
    }.update(options)
  end

  def reset_changes
    @options[:reset_changes] = true
    self
  end

  def reset_one_trans
    @options[:reset_one_trans] = true
    self
  end

  def one_trans_ie
    @options[:one_trans_ie] = true
    self
  end

  def focus(element_id)
    @options[:focus] = element_id
    self
  end

  def spinner_off
    @options[:spinner_off] = true
    self
  end

  def scroll_top
    @options[:scroll_top] = true
    self
  end

  def load_chart(chart_data)
    @options[:load_chart] = chart_data
    self
  end

  def show_miq_buttons(show = true)
    @options[:show_miq_buttons] = show
    self
  end

  def set_visibility(value, *elements)
    elements.each { |el| @options[:set_visible_elements][el] = value }
    self
  end

  def lock_tree(tree, lock = true)
    @options[:lock_unlock_trees][tree] = !!lock
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

  def self.open_window(url)
    new(:mode => 'window', :open_url => url)
  end

  def []=(key, value)
    @options[key] = value
  end

  def [](key)
    @options[key]
  end

  def for_render
    case @options[:mode]
    when 'main_div' then for_render_main_div
    when 'flash'    then for_render_flash
    when 'buttons'  then for_render_buttons
    when 'window'   then for_render_window
    else for_render_default
    end
  end

  private

  def for_render_flash
    data = {:explorer => 'flash'}
    data[:replacePartials] = @options[:replace_partials]
    data[:spinnerOff] = true if @options[:spinner_off]
    data[:scrollTop] = true if @options[:scroll_top]
    data[:focus] = @options[:focus] if @options[:focus]
    data
  end

  def for_render_window
    data = {:explorer => 'window'}
    data[:openUrl] = @options[:open_url]
    data[:spinnerOff] = true if @options[:spinner_off]
    data
  end

  def for_render_main_div
    data = check_spinner(:explorer => 'replace_main_div')
    data[:updatePartials] = @options[:update_partials]
    data
  end

  def check_spinner(data)
    data[:spinnerOff] = true if @options[:spinner_off]
    data
  end

  def for_render_buttons
    data = {:explorer => 'buttons'}
    data[:showMiqButtons] = @options[:show_miq_buttons]
    data
  end

  def for_render_default
    data = {:explorer => 'replace_right_cell', :scrollTop => true}

    if @options[:exp].present?
      data.store_path(:expEditor, :first, :type,   @options[:exp][:val1_type]) if @options[:exp][:val1_type]
      data.store_path(:expEditor, :first, :title,  @options[:exp][:val1_title]) if @options[:exp][:val1_title]
      data.store_path(:expEditor, :second, :type,  @options[:exp][:val2_type]) if @options[:exp][:val2_type]
      data.store_path(:expEditor, :second, :title, @options[:exp][:val2_title]) if @options[:exp][:val2_title]
    end

    data[:showMiqButtons] = @options[:show_miq_buttons]
    data[:clearTreeCookies] = @options[:clear_tree_cookies]

    # Open an accordion inside an other AJAX call
    data[:accordionSwap] = @options[:open_accord] unless @options[:open_accord].to_s.empty?

    data[:addNodes] = {
      :activeTree => @options[:active_tree],
      :key        => @options[:add_nodes][:key],
      :osf        => @options[:osf_node],
      :nodes      => @options[:add_nodes][:nodes],
      :remove     => !!@options[:remove_nodes],
    } if @options[:add_nodes]

    data[:deleteNode] = {
      :node       => @options[:delete_node],
      :activeTree => @options[:active_tree],
    } if @options[:delete_node]

    data[:dashboardUrl] = @options[:miq_widget_dd_url] if @options[:miq_widget_dd_url]
    data[:updatePartials] = @options[:update_partials] # Replace content of given DOM element (element stays).
    data[:updateElements] = @options[:element_updates] # Update element in the DOM with given options
    data[:replacePartials] = @options[:replace_partials] # Replace given DOM element (and it's children) (element goes away).
    data[:buildCalendar] = format_calendar_dates(@options[:build_calendar])
    data[:initDashboard] = !! @options[:init_dashboard]
    data[:ajaxUrl] = ajax_action_url(@options[:ajax_action]) if @options[:ajax_action]
    data[:clearGtlListGrid] = !!@options[:clear_gtl_list_grid]
    data[:setVisibility] = @options[:set_visible_elements]
    data[:rightCellText] = ERB::Util.html_escape(@options[:right_cell_text]) if @options[:right_cell_text]

    data[:reloadToolbars] = @options[:reload_toolbars].collect do |_div_name, toolbar|
      toolbar
    end

    data[:record] = {
      :parentId    => @options[:parent_id],
      :parentClass => @options[:parent_class],
      :recordId    => @options[:record_id],
    }

    unless @options[:osf_node].blank?
      data[:activateNode] = {
        :activeTree => @options[:active_tree],
        :osf        => @options[:osf_node]
      }
    end

    data[:lockTrees] = @options[:lock_unlock_trees]
    data[:chartData] = @options[:load_chart]
    data[:resetChanges] = !!@options[:reset_changes]
    data[:resetOneTrans] = !!@options[:reset_one_trans]
    data[:oneTransIE] = !!@options[:one_trans_ie]
    data[:focus] = @options[:focus]
    data[:clearSearch] = @options[:clear_search_toggle] if @options[:clear_search_toggle]
    data[:hideModal] if @options[:hide_modal]
    data[:initAccords] if @options[:init_accords]

    data
  end

  def format_calendar_dates(options)
    return {} unless @options[:build_calendar].kind_of?(Hash)
    %i(date_from date_to).each_with_object({}) do |key, h|
      h[key] = options[key].iso8601 if options[key].present?
    end
  end

  def ajax_action_url(options)
    ['', options[:controller], options[:action], options[:record_id]].join('/')
  end
end
