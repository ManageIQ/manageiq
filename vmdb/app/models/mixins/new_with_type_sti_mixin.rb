# Derived from: http://coderrr.wordpress.com/2008/04/22/building-the-right-class-with-sti-in-rails/

module NewWithTypeStiMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def new(*args, &block)
      if (h = args.first).is_a?(Hash) && (type = h[inheritance_column.to_sym] || h[inheritance_column.to_s])
        klass = type.constantize
        raise "#{klass.name} is not a subclass of #{self.name}" unless klass <= self
        args.unshift(args.shift.except(inheritance_column.to_sym, inheritance_column.to_s))
        klass.new(*args, &block)
      else
        super
      end
    end
  end
end
