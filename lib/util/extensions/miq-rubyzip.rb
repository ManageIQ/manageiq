require 'zip/zipfilesystem'

if Zip::VERSION == '0.9.1'

  module Zip
    class ZipEntry
      def time
        if @extra["UniversalTime"] && @extra["UniversalTime"].mtime
          @extra["UniversalTime"].mtime
        else
          @time
        end
      end

      def mtime
        self.time
      end
    end

    class ZipExtraField
      class UniversalTime
        def pack_for_local
          s = [@flag || 0].pack("C")
          @flag & 1 != 0 and s << [@mtime.to_i].pack("V")
          @flag & 2 != 0 and s << [@atime.to_i].pack("V")
          @flag & 4 != 0 and s << [@ctime.to_i].pack("V")
          s
        end
        def pack_for_c_dir
          s = [@flag || 0].pack("C")
          @flag & 1 == 1 and s << [@mtime.to_i].pack("V")
          s
        end
      end
    end
  end

end
