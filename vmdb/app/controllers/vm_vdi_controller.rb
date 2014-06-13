class VmVdiController < VdiBaseController
  include VmCommon        # common methods for vm/vdi vm controllers

  def self.model
    @model ||= VmVdi
  end

  def self.table_name
    @table_name ||= "vm_vdi"
  end

  def index
    session[:vm_vdi_type] = nil             # Reset VM type if coming in from All tab
    process_index
  end

  def show_list
    session[:vm_vdi_type] = params[:vmtyp] if params[:vmtyp]
    process_show_list
  end

  private ###########################

  def get_session_data
    @filters = session[:vm_vdi_filters]
    @title      = ui_lookup(:tables => self.class.table_name)
    @layout     = self.class.table_name
    @lastaction = session["#{self.class.session_key_prefix}_lastaction".to_sym]
    @showtype   = session["#{self.class.session_key_prefix}_showtype".to_sym]
    @display    = session["#{self.class.session_key_prefix}_display".to_sym]
  end

  def set_session_data
    session[:vm_vdi_filters] = @filters
    session["#{self.class.session_key_prefix}_lastaction".to_sym] = @lastaction
    session["#{self.class.session_key_prefix}_showtype".to_sym]   = @showtype
    session["#{self.class.session_key_prefix}_display".to_sym]    = @display.nil? ? session["#{self.class.session_key_prefix}_display".to_sym] : @display
  end
end
