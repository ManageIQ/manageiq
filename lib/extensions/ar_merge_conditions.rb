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
      [:select, :select]
    ]

    def self.apply_legacy_finder_options(options)
      unknown_keys = options.keys - LEGACY_FINDER_METHODS.map(&:first)
      raise "Unsupported options #{unknown_keys}" unless unknown_keys.empty?

      # Determine whether any of the included associations are polymorphic
      has_polymorphic = included_associations(options[:include]).any? { |name| self.reflection_is_polymorphic?(name) }

      LEGACY_FINDER_METHODS.inject(all) do |scope, (key, method)|
        # Don't call references method on scope if polymorphic associations are
        # included to avoid ActiveRecord::EagerLoadPolymorphicError
        next(scope) if method == :references && has_polymorphic
        #
        options[key] ? scope.send(method, options[key]) : scope
      end
    end

    def self.reflection_is_polymorphic?(name)
      reflection = _reflect_on_association(name)
      reflection ? reflection.polymorphic? : false
    end

    def self.included_associations(includes)
      arr = []
      _included_associations includes, arr
      arr
    end

    def self._included_associations(includes, arr)
      case includes
      when Symbol, String
        arr << includes.to_sym
      when Array
        includes.each do |assoc|
          _included_associations assoc, arr
        end
      when Hash
        includes.each do |k, v|
          cache = arr << k
          _included_associations v, cache
        end
      end
    end
  end
end
