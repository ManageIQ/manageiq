module MiqAeCopyMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def split(fqname, has_instance_name)
      ns, ae_class, ae_instance, _  = MiqAeEngine::MiqAePath.split(fqname, :has_instance_name => has_instance_name)
      parts = ns.split('/')
      domain = parts.shift
      partial_ns = parts.join('/')
      return domain, partial_ns, ae_class, ae_instance if has_instance_name
      return domain, partial_ns, ae_class
    end

    def same_class(from_class, to_class)
      diff_obj = MiqAeClassCompareFields.new(from_class, to_class)
      diff_obj.compare
      diff_obj.congruent?
    end
  end
end
