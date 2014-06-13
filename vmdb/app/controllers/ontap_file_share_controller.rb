class OntapFileShareController < CimInstanceController

  def index
    process_index
  end

  def button
    process_button
  end

  def show
    process_show(
      'cim_base_storage_extents' => :base_storage_extents,
      'vms'                      => :vms,
      'hosts'                    => :hosts,
      'storages'                 => :storages
    )
  end

  def show_list
    process_show_list
  end

  # Create a datastore on a storage system
  def create_ds
    case params[:button]
    when "cancel"
      create_ds_cancel
    when "submit"
      create_ds_submit
    else  # First time in
      create_ds_init
    end

  end

  # Handle create datastore field changes
  def create_ds_field_changed
    id = params[:id]
    return unless load_edit("ontap_file_share_create_ds__#{id}")

    @edit[:new][:ds_name] = params[:ds_name] if params[:ds_name]
    @edit[:new][:host_id] = params[:host_id] if params[:host_id]
    render :nothing => true                                 # No response needed
  end

  private ############################

  # Handle the create_datastore button
  def create_datastore
    return unless request.parameters[:controller] == "ontap_file_share"
    @sb[:sfs_id] = params[:id]
    @record = OntapFileShare.find(params[:id])
    render :update do |page|
      area = request.parameters["controller"]
      if role_allows(:feature=>"#{area}_tag")
        page.redirect_to :action => 'create_ds'
      else
        add_flash(I18n.t("flash.user_not_authorized"), :error)
        page.replace(:flash_msg_div, :partial=>"layouts/flash_msg")
      end
    end
  end

  def create_ds_init
    @sfs = OntapFileShare.find(@sb[:sfs_id])
    drop_breadcrumb( {:name=>"Create Datastore", :url=>"/#{session[:controller]}/create_ds"} )

    @gtl_type = "list"
    create_ds_set_form_vars
    @in_a_form = true
    session[:changed] = false
    @create_ds = true
    render :action=>"show"
  end

  def create_ds_submit
    return unless load_edit("ontap_file_share_create_ds__#{params[:id]}")
    sfs = OntapFileShare.find(@sb[:sfs_id])
    if create_ds_valid? &&
        sfs.queue_create_datastore(@edit[:new][:ds_name],
                            Host.find(@edit[:new][:host_id]))
      add_flash(I18n.t("flash.record.task_started", :model=>ui_lookup(:model=>"OntapFileShare"), :name=>sfs.name, :task=>"Create Datastore"))
      @edit = nil # clean out the saved info
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to(@breadcrumbs[-2][:url])              # Go to previous breadcrumb
      end
    else
      sfs.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      render :update do |page|
        page.replace(:flash_msg_div, :partial=>"layouts/flash_msg")
      end
    end
  end

  def create_ds_cancel
    return unless load_edit("ontap_file_share_create_ds__#{params[:id]}")
    add_flash(I18n.t("flash.task_cancelled", :task=>"Create Datastore"))
    @edit = nil # clean out the saved info
    session[:flash_msgs] = @flash_array.dup                   # Put msgs in session for next transaction
    render :update do |page|
      page.redirect_to(@breadcrumbs[-2][:url])                # Go to previous breadcrumb
    end
  end

  # Set form vars for create_ds
  def create_ds_set_form_vars
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:key] = "ontap_file_share_create_ds__#{@sfs.id}"
    @edit[:new][:ds_name] = @sfs.default_datastore_name
    @edit[:hosts] = @sfs.applicable_hosts
  end

  def create_ds_valid?
    add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error) if @edit[:new][:ds_name].blank?
    add_flash(I18n.t("flash.edit.field_required", :field=>"Host"), :error) if @edit[:new][:host_id].blank?
    return @flash_array.nil?
  end

end
