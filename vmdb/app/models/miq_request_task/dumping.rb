module MiqRequestTask::Dumping
  extend ActiveSupport::Concern

  module ClassMethods
    def dumpObj(obj, prefix = nil, prnt_obj = STDOUT, prnt_meth = :puts, options = {})
      meth = "dump#{obj.class.name}".to_sym
      if self.respond_to?(meth)
        prnt_obj.send(prnt_meth, "#{prefix}(#{obj.class}) = EMPTY") if obj.respond_to?(:blank?) && obj.blank?
        send(meth, obj, prefix, prnt_obj, prnt_meth, options)
      else
        protected = false
        if options[:protected].kind_of?(Hash)
          protected = options[:protected][:path].to_miq_a.any? { |filter| prefix =~ filter }
        end
        if protected == true
          prnt_obj.send(prnt_meth, "#{prefix}(#{obj.class}) = <PROTECTED>")
        else
          prnt_obj.send(prnt_meth, "#{prefix}(#{obj.class}) = #{obj.inspect}")
        end
      end
    end

    def dumpWIN32OLE(obj, prefix, prnt_obj, prnt_meth, options)
      prnt_obj.send(prnt_meth, "#{prefix} (WIN32OLE)\n#{obj.GetObjectText_.strip} #{obj.Path_.Path}\n\n")
    end

    def dumpHash(hd, prefix, prnt_obj, prnt_meth, options)
      hd.each { |k, v| dumpObj(v, "#{prefix}[#{Symbol === k ? ":#{k}" : k}]", prnt_obj, prnt_meth, options) }
    end

    def dumpVimHash(hd, prefix, prnt_obj, prnt_meth, options)
      prnt_obj.send(prnt_meth, "#{prefix} (#{hd.class}) xsiType: <#{hd.xsiType}>  vimType: <#{hd.vimType}>")
      dumpHash(hd, prefix, prnt_obj, prnt_meth, options)
    end

    def dumpArray(ad, prefix, prnt_obj, prnt_meth, options)
      ad.inject(0) { |i, d| dumpObj(d, "#{prefix}[#{i}]", prnt_obj, prnt_meth, options);  i += 1 }
    end

    def dumpVimArray(ad, prefix, prnt_obj, prnt_meth, options)
      prnt_obj.send(prnt_meth, "#{prefix} (#{ad.class}) xsiType: <#{ad.xsiType}>  vimType: <#{ad.vimType}>")
      dumpArray(ad, prefix, prnt_obj, prnt_meth, options)
    end
  end

  def dumpObj(obj, prefix = nil, prnt_obj = STDOUT, prnt_meth = :puts, options = {})
    self.class.dumpObj(obj, prefix, prnt_obj, prnt_meth, options)
  end
end
