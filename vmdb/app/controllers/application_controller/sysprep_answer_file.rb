class ApplicationController
  module SysprepAnswerFile
    def upload_sysprep_file
      @_params.delete :commit
      @upload_sysprep_file = true
      @edit = session[:edit]
      build_grid
      if params.fetch_path(:upload, :file).respond_to?(:read)
        @edit[:new][:sysprep_upload_file] = params[:upload][:file].original_filename
        begin
          @edit[:new][:sysprep_upload_text] = MiqProvisionWorkflow.validate_sysprep_file(params[:upload][:file])
          msg = _('Sysprep "%s" upload was successful') % params[:upload][:file].original_filename
          add_flash(msg)
        rescue StandardError => bang
          @edit[:new][:sysprep_upload_text] = nil
          msg = _("Error during Sysprep \"%s\" file upload: ") % params[:upload][:file].original_filename <<
            bang.message
          add_flash(msg, :error)
        end
      else
        @edit[:new][:sysprep_upload_text] = nil
        msg = _("Use the Browse button to locate an Upload file")
        add_flash(msg, :error)
      end
    end
  end
end
