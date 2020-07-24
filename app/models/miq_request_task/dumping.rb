module MiqRequestTask::Dumping
  extend ActiveSupport::Concern

  module ClassMethods
    def dump_obj(obj, prefix = nil, print_obj = STDOUT, print_method = :puts, &block)
      meth = "dump_#{obj.class.name.underscore}".to_sym

      if self.respond_to?(meth)
        return send(meth, obj, prefix, print_obj, print_method, &block)
      end

      yield obj, prefix
    end

    def dump_hash(hd, prefix, print_obj, print_method, &block)
      hd.each { |k, v| dump_obj(v, "#{prefix}[#{k.inspect}]", print_obj, print_method, &block) }
    end

    def dump_array(ad, prefix, print_obj, print_method, &block)
      ad.each_with_index { |d, i| dump_obj(d, "#{prefix}[#{i}]", print_obj, print_method, &block) }
    end

    def dump_vim_hash(hd, prefix, print_obj, print_method, &block)
      print_obj.send(print_method, "#{prefix} (#{hd.class}) xsiType: <#{hd.xsiType}>  vimType: <#{hd.vimType}>")
      dump_hash(hd, prefix, print_obj, print_method, &block)
    end

    def dump_vim_array(ad, prefix, print_obj, print_method, &block)
      print_obj.send(print_method, "#{prefix} (#{ad.class}) xsiType: <#{ad.xsiType}>  vimType: <#{ad.vimType}>")
      dump_array(ad, prefix, print_obj, print_method, &block)
    end
  end

  def dump_obj(obj, prefix = nil, print_obj = STDOUT, print_method = :puts, options = {})
    self.class.dump_obj(obj, prefix, print_obj, print_method) do |val, key|
      value = val
      if Array.wrap(options.try(:[], :protected).try(:[], :path)).any? { |filter| key =~ filter }
        value = "<PROTECTED>"
      end
      print_obj.send(print_method, "#{key}(#{val.class}) = #{value.inspect}")
    end
  end
end
