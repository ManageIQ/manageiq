module DRb
  class DRbMessage
    def load(soc)  # :nodoc:
      begin
        sz = soc.read(4)        # sizeof (N)
      rescue
        raise(DRbConnError, $!.message, $!.backtrace)
      end
      raise(DRbConnError, 'connection closed') if sz.nil?
      raise(DRbConnError, 'premature header') if sz.size < 4
      sz = sz.unpack('N')[0]
      raise(DRbConnError, "too large packet #{sz}") if @load_limit < sz
      begin
        str = soc.read(sz)
      rescue
        raise(DRbConnError, $!.message, $!.backtrace)
      end
      raise(DRbConnError, 'connection closed') if str.nil?
      raise(DRbConnError, 'premature marshal format(can\'t read)') if str.size < sz
      DRb.mutex.synchronize do
        begin
          save = Thread.current[:drb_untaint]
          Thread.current[:drb_untaint] = []
          Marshal::load(str)
        rescue NameError, ArgumentError
          DRbUnknown.new($!, str)
        rescue TypeError => err
          raise TypeError, "#{err}\n#{str.hex_dump}"
        ensure
          Thread.current[:drb_untaint].each do |x|
            x.untaint
          end
          Thread.current[:drb_untaint] = save
        end
      end
    end
  end
end
