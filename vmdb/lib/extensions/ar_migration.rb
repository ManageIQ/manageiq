module ActiveRecord
  class Migration
    def create_table(table_name, options = {})
      options[:id] ||= :bigserial
      super
      return if options[:id] == false

      value = ActiveRecord::Base.rails_sequence_start
      set_pk_sequence!(table_name, value) unless value == 0
    end
  end
end
