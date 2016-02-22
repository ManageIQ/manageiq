class MiqAeToolsController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    resolve
  end

  def show
    @lastaction = "resolve"
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    if params[:pressed] == "refresh_log"
      refresh_log
      return
    end
    if params[:pressed] == "collect_logs"
      collect_logs
      return
    end

    unless @refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
  end

  def log
    @breadcrumbs = []
    @log = $miq_ae_logger.contents if $miq_ae_logger
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning) if @log.blank?
    @lastaction = "log"
    @layout = "miq_ae_logs"
    @msg_title = "AE"
    @download_action = "fetch_log"
    drop_breadcrumb(:name => "Log", :url => "/miq_ae_tools/log")
    render :action => "show"
  end

  def refresh_log
    assert_privileges("refresh_log")
    @log = $miq_ae_logger.contents if $miq_ae_logger
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning) if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("main_div", :partial => "layouts/log_viewer", :locals => {:legend_text => "Last 1000 lines from the Automation log"})
    end
  end

  # Send the log in text format
  def fetch_log
    assert_privileges("fetch_log")
    disable_client_cache
    send_data($miq_ae_logger.contents(nil, nil),
              :filename => "automation.log") if $miq_ae_logger
    AuditEvent.success(:userid => session[:userid], :event => "download_automation_log", :message => "Automation log downloaded")
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    get_form_vars
    render :update do |page|                    # Use JS to update the display
      if params.key?(:instance_name) || params.key?(:starting_object) ||
         params.key?(:target_class) || params.key?(:target_id) ||
         params.key?(:other_name) || params.key?(:target_attr_name)
        unless params.key?(:other_name) || params.key?(:target_attr_name)
          page.replace("resolve_form_div", :partial => "resolve_form")
        end
        if @resolve[:throw_ready]
          page << javascript_hide("throw_off")
          page << javascript_show("throw_on")
        else
          page << javascript_hide("throw_on")
          page << javascript_show("throw_off")
        end
      end
    end
  end

  def import_export
    @in_a_form = true
    @breadcrumbs = []
    drop_breadcrumb(:name => "Import / Export", :url => "/miq_ae_tools/import_export")
    @lastaction = "import_export"
    @layout = "miq_ae_export"
    @importable_domain_options = []
    MiqAeDomain.all_unlocked.collect do |domain|
      @importable_domain_options << [domain.name, domain.name]
    end

    editable_domains = current_tenant.editable_domains.collect(&:name)
    @importable_domain_options = @importable_domain_options.select do |importable_domain|
      editable_domains.include?(importable_domain[0])
    end

    @importable_domain_options.unshift(["<Same as import from>", nil])
    render :action => "show"
  end

  def automate_json
    begin
      automate_json = automate_import_json_serializer.serialize(ImportFileUpload.find(params[:import_file_upload_id]))
    rescue StandardError => e
      add_flash("Error: import processing failed: #{e.message}", :error)
    end

    respond_to do |format|
      if @flash_array && @flash_array.count
        format.json { render :json => @flash_array.first.to_json, :status => 500 }
      else
        format.json { render :json => automate_json }
      end
    end
  end

  def cancel_import
    automate_import_service.cancel_import(params[:import_file_upload_id])
    add_flash(_("Datastore import was cancelled or is finished"), :info)

    respond_to do |format|
      format.js { render :json => @flash_array.to_json, :status => 200 }
    end
  end

  def import_automate_datastore
    if params[:selected_namespaces].present?
      selected_namespaces = determine_all_included_namespaces(params[:selected_namespaces])
      import_file_upload = ImportFileUpload.where(:id => params[:import_file_upload_id]).first

      if import_file_upload
        import_stats = automate_import_service.import_datastore(
          import_file_upload,
          params[:selected_domain_to_import_from],
          params[:selected_domain_to_import_to],
          selected_namespaces.sort
        )

        stat_options = generate_stat_options(import_stats)

        add_flash(_("Datastore import was successful.
Namespaces updated/added: %{namespace_stats}
Classes updated/added: %{class_stats}
Instances updated/added: %{instance_stats}
Methods updated/added: %{method_stats}") % stat_options, :success)
      else
        add_flash(_("Error: Datastore import file upload expired"), :error)
      end
    else
      add_flash(_("You must select at least one namespace to import"), :info)
    end

    respond_to do |format|
      format.js { render :json => @flash_array.to_json, :status => 200 }
    end
  end

  def upload_import_file
    redirect_options = {:action => :review_import}

    upload_file = params.fetch_path(:upload, :file)

    if upload_file.blank?
      add_flash("Use the browse button to locate an import file", :warning)
    else
      import_file_upload_id = automate_import_service.store_for_import(upload_file.read)
      add_flash(_("Import file was uploaded successfully"), :success)
      redirect_options[:import_file_upload_id] = import_file_upload_id
    end

    redirect_options[:message] = @flash_array.first.to_json

    redirect_to redirect_options
  end

  def review_import
    @import_file_upload_id = params[:import_file_upload_id]
    @message = params[:message]
  end

  # Import classes
  def upload
    if params[:upload] && !params[:upload][:datastore].blank?
      begin
        MiqAeDatastore.upload(params[:upload][:datastore])
        add_flash(_("Datastore import was successful.
Namespaces updated/added: %{namespace_stats}
Classes updated/added: %{class_stats}
Instances updated/added: %{instance_stats}
Methods updated/added: %{method_stats}") % stat_options)
        redirect_to :action => 'import_export', :flash_msg => @flash_array[0][:message]         # redirect to build the retire screen
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "upload" << bang.message, :error)
        redirect_to :action => 'import_export', :flash_msg => @flash_array[0][:message], :flash_error => true         # redirect to build the retire screen
      end
    else
      @in_a_form = true
      add_flash(_("Use the Browse button to locate an Import file"), :error)
      #     render :action=>"import_export"
      import_export
    end
  end

  # Send all classes and instances
  def export_datastore
    filename = "datastore_" + format_timezone(Time.now, Time.zone, "fname") + ".zip"
    disable_client_cache
    send_data(MiqAeDatastore.export(current_tenant), :filename => filename)
  end

  # Reset all custom classes and instances to default
  def reset_datastore
    unless params[:task_id]                       # First time thru, kick off the report generate task
      initiate_wait_for_task(:task_id => MiqAutomate.async_datastore_reset)
      return
    end
    miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
    session[:ae_id] = params[:id]
    session[:ae_task_id] = params[:task_id]

    if miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
      add_flash(_("Error during %{task}: Status [%{status}] Message [%{message}]") % {:task => "reset", :status => miq_task.status, :message => miq_task.message}, :error)
    else
      self.x_node = "root" if x_active_tree == :ae_tree && x_tree
      add_flash(_("All custom classes and instances have been reset to default"))
    end
    render :update do |page|          # Use RJS to update the display
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << "miqSparkle(false);"
    end
  end

  private ###########################

  def automate_import_json_serializer
    @automate_import_json_serializer ||= AutomateImportJsonSerializer.new
  end

  def automate_import_service
    @automate_import_service ||= AutomateImportService.new
  end

  def add_stats(stats_hash)
    stats_hash.inject(0) do |result, key_value|
      result + key_value[1]
    end
  end

  def determine_all_included_namespaces(namespaces)
    namespaces.each do |namespace|
      potentially_missed_namespaces = determine_missed_namespaces(namespace)
      namespaces += potentially_missed_namespaces
    end

    namespaces.uniq
  end

  def generate_stat_options(import_stats)
    namespace_stats = add_stats(import_stats[:namespace])
    class_stats     = add_stats(import_stats[:class])
    instance_stats  = add_stats(import_stats[:instance])
    method_stats    = add_stats(import_stats[:method])

    {
      :namespace_stats => namespace_stats,
      :class_stats     => class_stats,
      :instance_stats  => instance_stats,
      :method_stats    => method_stats
    }
  end

  def determine_missed_namespaces(namespace)
    if namespace.match("/")
      [namespace, determine_missed_namespaces(namespace.split("/")[0..-2].join("/"))].flatten
    else
      [namespace]
    end
  end

  def ws_text_from_xml(xml, depth = 0)
    txt = ""
    if depth == 0
      txt += "<#{xml.root.name}>\n"
      xml.root.each_element do |e|
        txt += "  "
        txt += e.inspect + "\n"
        txt += ws_text_from_xml(e, depth + 2)
        txt += "  "
        txt += "<\\#{e.name}>\n"
      end
      txt += "<\\#{xml.root.name}>"
    else
      xml.each_element do |e|
        depth.times { txt += "  " }
        txt += e.inspect + "\n"
        txt += ws_text_from_xml(e, depth + 1)
        depth.times { txt += "  " }
        txt += "<\\#{e.name}>\n"
      end
    end
    txt
  end

  def ws_tree_from_xml(xml_string)
    xml = MiqXml.load(xml_string)
    top_nodes = []
    @idx = 0
    xml.root.each_element do |e|
      top_nodes.push(ws_tree_add_node(e))
    end
    top_nodes.to_json
  end

  def ws_tree_add_node(el)
    e_node = {}
    e_node[:key] = "e_#{@idx}"
    @idx += 1
    #   e_node['tooltip'] = "Host: #{@host.name}"
    e_node[:style] = "cursor:default"          # No cursor pointer
    e_node[:addClass] = "cfme-no-cursor-node"
    e_kids = []
    if el.name == "MiqAeObject"
      e_node[:title] = "#{el.attributes["namespace"]} <b>/</b> #{el.attributes["class"]} <b>/</b> #{el.attributes["instance"]}"
      e_node[:icon] = "q.png"
    elsif el.name == "MiqAeAttribute"
      e_node[:title] = el.attributes["name"]
      e_node[:icon] = "attribute.png"
    elsif !el.text.blank?
      e_node[:title] = el.text
      e_node[:icon] = "#{el.name.underscore}.png"
    else
      e_node[:title] = el.name
      e_node[:icon] = "#{e_node[:title].underscore}.png"
      el.attributes.each_pair do |k, v|
        a_node = {}
        a_node[:key] = "a_#{@idx}"
        @idx += 1
        a_node[:title] = "#{k} <b>=</b> #{v}"
        a_node[:icon] = "attribute.png"
        e_kids.push(a_node)
      end
    end
    el.each_element do |e|
      e_kids.push(ws_tree_add_node(e))
    end
    e_node[:children] = e_kids unless e_kids.empty?
    e_node
  end

  def valid_resolve_object?
    add_flash(_("%s must be selected") % "Starting Class", :error) if @resolve[:new][:starting_object].blank?
    add_flash(_("%s is required") % "Starting Process", :error) if @resolve[:new][:instance_name].blank? && @resolve[:new][:other_name].blank?
    add_flash(_("%s is required") % "Request", :error) if @resolve[:new][:object_request].blank?
    AE_MAX_RESOLUTION_FIELDS.times do |i|
      f = ("attribute_" + (i + 1).to_s)
      v = ("value_" + (i + 1).to_s)
      add_flash(_("%{val} missing for %{field}") % {:val => f.titleize, :field => v.titleize}, :error) if @resolve[:new][:attrs][i][0].blank? && !@resolve[:new][:attrs][i][1].blank?
      add_flash(_("%{val} missing for %{field}") % {:val => v.titleize, :field => f.titleize}, :error) if !@resolve[:new][:attrs][i][0].blank? && @resolve[:new][:attrs][i][1].blank?
    end
    !flash_errors?
  end

  def get_form_vars
    if params.key?(:starting_object)
      @resolve[:new][:starting_object] = params[:starting_object]
      @resolve[:new][:instance_name] = nil
    end
    if params[:readonly]
      @resolve[:new][:readonly] = (params[:readonly] != "1")
    end
    @resolve[:new][:instance_name] = params[:instance_name] if params.key?(:instance_name)
    @resolve[:new][:other_name] = params[:other_name] if params.key?(:other_name)
    @resolve[:new][:object_message] = params[:object_message] if params.key?(:object_message)
    @resolve[:new][:object_request] = params[:object_request] if params.key?(:object_request)
    AE_MAX_RESOLUTION_FIELDS.times do |i|
      f = ("attribute_" + (i + 1).to_s)
      v = ("value_" + (i + 1).to_s)
      @resolve[:new][:attrs][i][0] = params[f] if params[f.to_sym]
      @resolve[:new][:attrs][i][1] = params[v] if params[v.to_sym]
    end
    @resolve[:new][:target_class] = params[:target_class] if params[:target_class]
    #   @resolve[:new][:target_attr_name] = params[:target_attr_name] if params.has_key?(:target_attr_name)
    if params.key?(:target_class)
      @resolve[:new][:target_class] = params[:target_class]
      klass = CustomButton.name_to_button_class(params[:target_class])
      unless klass.nil?
        targets = klass.all
        @resolve[:targets] = targets.sort_by { |t| t.name.downcase }.collect { |t| [t.name, t.id.to_s] }
        @resolve[:new][:target_id] = nil
      end
    end
    @resolve[:new][:target_id] = nil if params[:target_class] == ""
    @resolve[:new][:target_id] = params[:target_id] if params.key?(:target_id)
    @resolve[:button_text] = params[:button_text] if params.key?(:button_text)
    @resolve[:button_number] = params[:button_number] if params.key?(:button_number)
    @resolve[:throw_ready] = ready_to_throw
  end

  def get_session_data
    @layout  = "miq_ae_tools"
    @resolve = session[:resolve] if session[:resolve]
  end

  def set_session_data
    session[:resolve] = @resolve if @resolve
  end
end
