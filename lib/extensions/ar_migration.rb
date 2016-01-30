module ActiveRecord
  class Migration
    def create_table(table_name, options = {})
      options[:id] = :bigserial if options[:id].nil?
      super
      return if options[:id] == false

      value = ApplicationRecord.rails_sequence_start
      set_pk_sequence!(table_name, value) unless value == 0
    end
  end
end
