module Mixins
  module GenericSessionMixin

    private

    def get_session_data
      @title      = ui_lookup(:tables => self.class.table_name)
      @layout     = self.class.table_name
      @table_name = request.parameters[:controller]
      @lastaction = session["#{self.class.table_name}_lastaction".to_sym]
      @display    = session["#{self.class.table_name}_display".to_sym]
      @filters    = session["#{self.class.table_name}_filters".to_sym]
      @catinfo    = session["#{self.class.table_name}_catinfo".to_sym]
      @showtype   = session["#{self.class.table_name}_showtype".to_sym]
    end

    def set_session_data
      session["#{self.class.table_name}_lastaction".to_sym] = @lastaction
      session["#{self.class.table_name}_display".to_sym]    = @display unless @display.nil?
      session["#{self.class.table_name}_filters".to_sym]    = @filters
      session["#{self.class.table_name}_catinfo".to_sym]    = @catinfo
      session["#{self.class.table_name}_showtype".to_sym]   = @showtype
    end
  end
end
