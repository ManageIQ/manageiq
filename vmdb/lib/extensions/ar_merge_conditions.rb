# TODO: Ported from Rails 2.3.8.  Remove once we move to Arel queries
module ActiveRecord
  class Base
    def self.merge_conditions(*conditions)
      ActiveSupport::Deprecation.warn "merge_conditions is old and busted; use Relation API instead", caller

      segments = []

      ActiveSupport::Deprecation.silence do
        conditions.each do |condition|
          unless condition.blank?
            sql = sanitize_sql(condition)
            segments << sql unless sql.blank?
          end
        end
      end

      "(#{segments.join(') AND (')})" unless segments.empty?
    end

    LEGACY_FINDER_METHODS = [
      [:conditions, :where],
      [:include, :includes],
      [:include, :references],
      [:limit, :limit],
      [:order, :order],
      [:offset, :offset],
    ]

    def self.apply_legacy_finder_options(options)
      unknown_keys = options.keys - LEGACY_FINDER_METHODS.map(&:first)
      raise "Unsupported options #{unknown_keys}" unless unknown_keys.empty?

      LEGACY_FINDER_METHODS.inject(all) { |scope, (key, method)|
        options[key] ? scope.send(method, options[key]) : scope
      }
    end
  end
end
