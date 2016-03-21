module Mixins
  module GenericSessionMixin
    private
    def get_session_data
      @title      = self.class.title
      @layout     = self.class.table_name
      @lastaction = session["#{self.class.table_name}_lastaction".to_sym]
      @display    = session["#{self.class.table_name}_display".to_sym]
      @filters    = session["#{self.class.table_name}_filters".to_sym]
      @catinfo    = session["#{self.class.table_name}_catinfo".to_sym]
    end

    def set_session_data
      session["#{self.class.table_name}_lastaction".to_sym] = @lastaction
      session["#{self.class.table_name}_display".to_sym]    = @display unless @display.nil?
      session["#{self.class.table_name}_filters".to_sym]    = @filters
      session["#{self.class.table_name}_catinfo".to_sym]    = @catinfo
    end
  end
end
