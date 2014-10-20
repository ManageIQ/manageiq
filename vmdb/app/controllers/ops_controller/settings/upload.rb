module OpsController::Settings::Upload
  extend ActiveSupport::Concern

  logo_dir = File.expand_path(File.join(Rails.root, "public/upload"))
  Dir.mkdir logo_dir unless File.exists?(logo_dir)
  @@logo_file = File.join(logo_dir, "custom_logo.png")
  @@login_logo_file = File.join(logo_dir, "custom_login_logo.png")
  def upload_logo
    upload_logos("custom")
  end

  def upload_login_logo
    upload_logos("login")
  end

  def upload_logos(typ)
    fld = typ == "custom" ? "upload" : "login"
    if params["#{fld}".to_sym] && params["#{fld}".to_sym][:logo] &&
        params["#{fld}".to_sym][:logo].respond_to?(:read)
      if params["#{fld}".to_sym][:logo].original_filename.split(".").last.downcase != "png"
        msg = I18n.t(typ == "custom" ? "flash.ops.settings.custom_logo_type" : "flash.ops.settings.custom_login_type")
        err = true
      else
        File.open(typ == "custom" ? @@logo_file : @@login_logo_file, "wb") { |f| f.write(params["#{fld}".to_sym][:logo].read) }
        msg = I18n.t(typ == "custom" ? "flash.ops.settings.custom_logo_uploaded" : "flash.ops.settings.custom_login_uploaded",
          :filename=>params["#{fld}".to_sym][:logo].original_filename)
        err = false
      end
    else
      msg = I18n.t("flash.ops.settings.locate_file", :typ=>".png image")
      err = true
    end
    redirect_to :action => 'explorer', :flash_msg=>msg, :flash_error=>err, :no_refresh=>true
  end

  def upload_form_field_changed
    return unless load_edit("settings_#{params[:id]}_edit__#{@sb[:selected_server_id]}","replace_cell__explorer")
    @edit[:new][:upload_type] = !params[:upload_type].nil? && params[:upload_type] != "" ? params[:upload_type] : nil
    msg = !params[:upload_type].nil? && params[:upload_type] != "" ? "Locate and upload a file to start the import process" : "Choose the type of custom variables to be imported"
    add_flash(msg)
    @sb[:good] = nil
    render :update do |page|                    # Use JS to update the display
      page.replace_html("settings_import", :partial=>"settings_import_tab")
    end
  end

  def upload_csv
    return unless load_edit("#{@sb[:active_tab]}_edit__#{@sb[:selected_server_id]}","replace_cell__explorer")
    err = false
    @flash_array = Array.new
    if params[:upload] && params[:upload][:file] && params[:upload][:file].respond_to?(:read)
      begin
        require 'miq_bulk_import'
        case params[:typ]
        when "tag"
          imp = ClassificationImport.upload(params[:upload][:file])
        when "asset_tag"
          case @edit[:new][:upload_type]
          when "host"
            imp = AssetTagImport.upload('Host', params[:upload][:file])
          when "vm"
            imp = AssetTagImport.upload('VmOrTemplate', params[:upload][:file])
          end
        end
      rescue StandardError => bang
         msg = I18n.t("flash.error_during", :task=>"upload") << bang
         err = true
      else
        imp.errors.each do |field,msg|
          msg = msg
          err = true
        end
        add_flash(I18n.t("flash.ops.settings.import_validation_complete",
            :good_record=>pluralize(imp.stats[:good], 'good record'),
            :bad_record=>pluralize(imp.stats[:bad], 'bad record')), :warning)
        if imp.stats[:good] == 0
           msg = _("No valid import records were found, please upload another file")
           err = true
        else
          msg = _("Press the Apply button to import the good records into the CFME database")
          err = false
          @sb[:good] = imp.stats[:good]
          @sb[:imports] = imp
        end
      end
    else
      msg = I18n.t("flash.ops.settings.locate_file", :typ=>"CSV")
      err = true
    end
    @sb[:show_button] = (@sb[:good] && @sb[:good] > 0)
    redirect_to :action => 'explorer', :flash_msg=>msg, :flash_error=>err, :no_refresh=>true
  end

  private

end
