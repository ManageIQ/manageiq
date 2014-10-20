class OntapStorageSystemController < CimInstanceController

  def index
    process_index
  end

  def button
    process_button
  end

  def show
    process_show(
      'cim_base_storage_extents' => :base_storage_extents,
      'ontap_logical_disks'      => :logical_disks,
      'ontap_storage_volume'     => :storage_volumes,
      'ontap_file_share'         => :hosted_file_shares,
      'snia_local_file_systems'  => :local_file_systems,
      'vms'                      => :vms,
      'hosts'                    => :hosts,
      'storages'                 => :storages
    )
  end

  def show_list
    process_show_list
  end

  # Create a datastore on a storage system
  def create_ld
    case params[:button]
    when "cancel"
      create_ld_cancel
    when "submit"
      create_ld_submit
    else  # First time in
      create_ld_init
    end

  end

  # Handle create logical disk field changes
  def create_ld_field_changed
    id = params[:id]
    return unless load_edit("ontap_storage_system_create_ld__#{id}")

    @edit[:new][:ld_name] = params[:ld_name] if params[:ld_name]
    @edit[:new][:aggregate_name] = params[:aggregate_name] if params[:aggregate_name]
    @edit[:new][:ld_size] = params[:ld_size] if params[:ld_size]
    render :nothing => true                                 # No response needed
  end

  private ############################

  # Handle the create_logical_disk button
  def create_logical_disk
    return unless request.parameters[:controller] == "ontap_storage_system"
    @sb[:ccs_id] = params[:id]
    @record = OntapStorageSystem.find(params[:id])
    render :update do |page|
      area = request.parameters["controller"]
      if role_allows(:feature=>"#{area}_tag")
        page.redirect_to :action => 'create_ld'
      else
        add_flash(_("The user is not authorized for this task or item."), :error)
        page.replace(:flash_msg_div, :partial=>"layouts/flash_msg")
      end
    end
  end

  def create_ld_init
    @ccs = OntapStorageSystem.find(@sb[:ccs_id])
    drop_breadcrumb( {:name=>"Create Logical Disk", :url=>"/#{session[:controller]}/create_ds"} )

    @gtl_type = "list"
    create_ld_set_form_vars
    @in_a_form = true
    session[:changed] = false
    @create_ld = true
    render :action=>"show"
  end

  def create_ld_submit
    return unless load_edit("ontap_storage_system_create_ld__#{params[:id]}")
    ccs = OntapStorageSystem.find(@sb[:ccs_id])
    if create_ld_valid? &&
        ccs.create_logical_disk(@edit[:new][:ld_name],
                                @edit[:new][:aggregate_name],
                                @edit[:new][:ld_size].to_i)
      add_flash(I18n.t("flash.record.task_started", :model=>ui_lookup(:model=>"OntapStorageSystem"), :name=>ccs.name, :task=>"Create Logical Disk"))
      @edit = nil # clean out the saved info
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to(@breadcrumbs[-2][:url])                # Go to previous breadcrumb
      end
    else
      ccs.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      render :update do |page|
        page.replace(:flash_msg_div, :partial=>"layouts/flash_msg")
      end
    end
  end

  def create_ld_cancel
    return unless load_edit("ontap_storage_system_create_ld__#{params[:id]}")
    add_flash(I18n.t("flash.task_cancelled", :task=>"Create Logical Disk"))
    @edit = nil # clean out the saved info
    session[:flash_msgs] = @flash_array.dup                   # Put msgs in session for next transaction
    render :update do |page|
      page.redirect_to(@breadcrumbs[-2][:url])                # Go to previous breadcrumb
    end
  end

  # Set form vars for create_ld
  def create_ld_set_form_vars
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:key] = "ontap_storage_system_create_ld__#{@ccs.id}"
    aggregates = @ccs.available_aggregates
    @edit[:aggregates] = aggregates ? aggregates : Hash.new
#   @edit[:aggregates] = {"one"=>"One (1 GB)", "two"=>"Two (2 GB)"}
  end

  def create_ld_valid?
    add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error) if @edit[:new][:ld_name].blank?
    add_flash(I18n.t("flash.edit.field_required", :field=>"Aggregate"), :error) if @edit[:new][:aggregate_name].blank?
    add_flash(I18n.t("flash.edit.field_required", :field=>"Size"), :error) if @edit[:new][:ld_size].blank?
    add_flash(I18n.t("flash.edit.field_must_be.integer", :field=>"Size"), :error) if @edit[:new][:ld_size] && (@edit[:new][:ld_size] =~ /^[-+]?[0-9]*[0-9]+$/).nil?
    return @flash_array.nil?
  end
end
