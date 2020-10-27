module ActsAsStiLeafClass
  extend ActiveSupport::Concern

  module ClassMethods
    def acts_as_sti_leaf_class?
      true
    end

    private def type_condition(table = arel_table)
      sti_column = table[inheritance_column]
      predicate_builder.build(sti_column, [sti_name])
    end
  end
end
