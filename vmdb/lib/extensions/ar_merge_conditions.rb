# TODO: Ported from Rails 2.3.8.  Remove once we move to Arel queries
module ActiveRecord
  class Base
    def self.merge_conditions(*conditions)
      segments = []

      conditions.each do |condition|
        unless condition.blank?
          sql = sanitize_sql(condition)
          segments << sql unless sql.blank?
        end
      end

      "(#{segments.join(') AND (')})" unless segments.empty?
    end
  end
end
