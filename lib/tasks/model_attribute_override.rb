module GettextI18nRails
  class ModelAttributesFinder
    def model_attributes(model, ignored_tables, ignored_cols)
      return [] if model.abstract_class? && Rails::VERSION::MAJOR < 3

      if model.abstract_class?
        model.direct_descendants.reject {|m| ignored?(m.table_name, ignored_tables)}.inject([]) do |attrs, m|
          attrs.push(model_attributes(m, ignored_tables, ignored_cols)).flatten.uniq
        end
      elsif !ignored?(model.table_name, ignored_tables) && @existing_tables.include?(model.table_name)
        list = model.virtual_attribute_names +
          model.columns.reject { |c| ignored?(c.name, ignored_cols) }.collect { |c| c.name }
        list
      else
        []
      end
    end
  end
end
