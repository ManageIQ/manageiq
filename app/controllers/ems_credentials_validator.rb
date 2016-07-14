module EmsCredentialsValidator
  # Method for generating validation object out of record_vars.
  # @see set_record_vars for more information about validation.
  # returns: object with details (about validation) and reulst status of validation.
  def create_validation_object(verify_ems)
    set_record_vars(verify_ems, :validate)
    @in_a_form = true

    #if no active request available we are creating new object
    @changed = @_request != nil ? session[:changed] : false

    # validate button should say "revalidate" if the form is unchanged
    revalidating = !edit_changed?
    result, details = verify_ems.authentication_check(params[:type], :save => revalidating)
    {:details => details, :result => result}
  end

  # Method rendering flash message about validation status
  # @see create_validation_object for more information about validation.
  def validate_credentials(verify_ems)
    result_object = create_validation_object verify_ems
    if result_object[:result]
      add_flash(_("Credential validation was successful"))
    else
      add_flash(_("Credential validation was not successful: %{details}") %
      {:details => result_object[:details]}, :error)
    end

    render_flash
  end
end
