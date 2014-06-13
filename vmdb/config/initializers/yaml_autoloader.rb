# Autoload Rails Models
# see https://github.com/collectiveidea/delayed_job/blob/master/lib/delayed/psych_ext.rb
module Psych
  module Visitors
    class ToRuby # ruby-1.9.3-p125/lib/ruby/1.9.1/psych/visitors/to_ruby.rb
      def resolve_class_with_constantize(klass_name)
        klass_name.constantize
      rescue
        resolve_class_without_constantize(klass_name)
      end
      alias_method_chain :resolve_class, :constantize
    end
  end
end
