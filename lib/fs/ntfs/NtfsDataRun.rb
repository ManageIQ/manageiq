$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'MiqMemory'

module NTFS
	
	class DataRun

    DEBUG_TRACE_READS = false
	  
		OffsetCode = {
			1 => [0xffffff00, 'L', 'l'],
			2 => [0xffff0000, 'L', 'l'],
			3 => [0xff000000, 'L', 'l'],
			4 => [0x00000000, 'L', 'l'],
			5 => [0xffffff0000000000, 'Q', 'q'],
			6 => [0xffff000000000000, 'Q', 'q'],
			7 => [0xff00000000000000, 'Q', 'q'],
			8 => [0x0000000000000000, 'Q', 'q']
		}
	  
		attr_reader :runSpec, :boot_sector, :length, :pos
	  
		def initialize(bs, buf, header)
			raise "MIQ(NTFS::DataRun.initialize) Nil boot sector" if bs.nil?
			raise "MIQ(NTFS::DataRun.initialize) Nil buffer"      if buf.nil?
	          
			# Buffer boot sector & start spec array.
			@boot_sector     = bs
			@bytesPerCluster = bs.bytesPerCluster
			@header					 = header
			@runSpec         = Array.new
			self.rewind
			
			# Read bytes until 0.
			#puts "specification is:"
      #buf.hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
			
			last_lcn = 0
			spec_pos = 0
			total_clusters = 0
			while buf[spec_pos,1].ord != 0
				#print "spec 0x#{'%02x' % buf[spec_pos]}\n"
				
				# Size of offset is hi nibble, size of length is lo nibble.
				size_of_offset, size_of_length = buf[spec_pos,1].ord.divmod(16)
        spec_pos += 1
				#puts "size_of_length 0x#{'%08x' % size_of_length}"
				#puts "size_of_offset 0x#{'%08x' % size_of_offset}"
				
				# Get length of run (number of clusters).
				run_length = suckBytes(buf[spec_pos, size_of_length])
				spec_pos += size_of_length
				#puts "length      0x#{'%08x' % run_length}"
	      
				# Get offset (offset from previous cluster).
				run_offset = suckBytes(buf[spec_pos, size_of_offset])
				spec_pos += size_of_offset
				#puts "offset      0x#{'%08x' % run_offset}"
	      
				# Offset is signed (only check if size gt 0. 0 size means 0 offset means sparse run).
				if size_of_offset > 0
					hi_bit = 2 ** (8 * size_of_offset - 1) #1 << (8 * size_of_offset - 1)
					# If this goofy number is negative, make it negative.
					if run_offset & hi_bit == hi_bit
						run_offset |= OffsetCode[size_of_offset][0]
						run_offset = [run_offset].pack(OffsetCode[size_of_offset][1]).unpack(OffsetCode[size_of_offset][2])[0]
					end
				end
				#puts "offset      0x#{'%08x' % run_offset}"
	      
	      # Not Sparse
	      if size_of_offset > 0
  	      lcn = run_offset + last_lcn
  	      last_lcn = lcn
  	    else
  	      lcn = nil
	      end
	      
				# Store run spec.
				total_clusters += run_length
				@runSpec << lcn
				@runSpec << run_length
			end
			@length = header.specific['data_size']
			@length = total_clusters * @bytesPerCluster if @length == 0

      # Cache the clusters we've already read.
      @clusters = Hash.new
		end
	  
		def to_s
		#	@current_run
		end
		
	  def addRun(r)
	    @runSpec += r.runSpec
	    @length  += r.length
    end
    
    def [](what)
      if what.class == Range
        offset = what.begin
        len    = what.end - what.begin + 1
        return self.[](offset,len)
      end
      
      if what.instance_of?(Integer)
        return self.[](what,1)
      end
      
      raise "MIQ(NTFS::DataRun.[]) Invalid Class (#{what.class})"
    end
    
    def [](offset,len)
      seek(offset)
      read(len)
    end
	  
		def rewind
			@pos = 0
		end
	  
	  def seek(offset, method = IO::SEEK_SET)
			@pos = case method
				when IO::SEEK_SET then offset
				when IO::SEEK_CUR then @pos + offset
				when IO::SEEK_END then @length - offset
			end
			@pos = 0 if @pos < 0
			@pos = @length if @pos > @length
			return @pos
		end

    def seekToVcn(vcn)
      seek(vcn * @bytesPerCluster)
    end

    def read(bytes = @length)
			return nil if @pos >= @length
      $log.info "#{self.class} #{self.object_id}: Reading #{bytes} bytes @ #{@pos}" if DEBUG_TRACE_READS

			startCluster, startOffset = @pos.divmod(@bytesPerCluster)
			endCluster, endOffset = (@pos + (bytes - 1)).divmod(@bytesPerCluster)

      ret = getClusters(startCluster, endCluster)
      ret = ret[startOffset..endOffset-@bytesPerCluster]
      @pos += ret.length

      return ret
		end

    def getClusters(start_vcn, end_vcn = nil)
      end_vcn = start_vcn if end_vcn.nil?

      # Single cluster
      if start_vcn == end_vcn && @clusters.has_key?(start_vcn)
        $log.info "#{self.class} #{self.object_id}: Reading clusters [#{start_vcn}, 1, true]" if DEBUG_TRACE_READS
        return readCachedClusters(start_vcn, 1)[0]
      end

      # Multiple clusters (part of which may be cached)
      num = end_vcn - start_vcn + 1
      ret = MiqMemory.create_zero_buffer(num * @bytesPerCluster)
      offset = 0
      
      to_read = findCachedClusters(start_vcn, end_vcn)
      $log.info "#{self.class} #{self.object_id}: Reading clusters #{to_read.inspect}" if DEBUG_TRACE_READS
      to_read.each_slice(3) do |vcn, len, cached|
        clusters = cached ? readCachedClusters(vcn, len) : readRawClusters(vcn, len)
        clusters.each do |c|
          len = c.length
          ret[offset, len] = c
          offset += len
        end
      end

      addClusterCache(start_vcn, ret)

      return ret
    end

    def findCachedClusters(start_vcn, end_vcn)
      to_read = []
      cur = run = last_cached = nil

      start_vcn.upto(end_vcn) do |vcn|
        check_last_cached = @clusters.has_key?(vcn)
        if last_cached == check_last_cached
          run += 1
        else
          to_read << cur << run << last_cached unless last_cached.nil?
          last_cached = check_last_cached
          cur = vcn
          run = 1
        end
      end
      to_read << cur << run << last_cached

      return to_read
    end

    def readCachedClusters(vcn, num)
      ret = []

      while num > 0
        data, start_vcn, end_vcn, data_len, offset = getCacheInfo(vcn)

        len = data_len - offset
        len = num if num < len

        ret << data[offset * @bytesPerCluster, len * @bytesPerCluster]

        num -= len
        vcn += len
      end

      return ret
    end

    def addClusterCache(start_vcn, data)
      end_vcn = start_vcn + (data.length / @bytesPerCluster) - 1

      has_start = @clusters.has_key?(start_vcn)
      start_data, start_data_vcn, = getCacheInfo(start_vcn) if has_start

      has_end = @clusters.has_key?(end_vcn)
      end_data, end_data_vcn, end_data_end_vcn, end_data_len, end_offset = getCacheInfo(end_vcn) if has_end

      # Determine if we are adding an existing item or sub-item back into the cache
      return if has_start && has_end && start_data_vcn == end_data_vcn

      # Determine if we are overlapping an existing cached item at the start
      if has_start && start_data_vcn != start_vcn
        leftover_len = start_vcn - start_data_vcn
        leftover = start_data[0, leftover_len * @bytesPerCluster]

        # Recache only the leftover portion
        @clusters[start_data_vcn] = leftover
      end

      # Determine if we are overlapping an existing cached item at the end
      if has_end && end_data_end_vcn != end_vcn
        leftover_start_vcn = end_vcn + 1
        leftover = end_data[(end_offset + 1) * @bytesPerCluster..-1]

        # Recache only the leftover portion
        @clusters[leftover_start_vcn] = leftover
        (leftover_start_vcn + 1..end_data_end_vcn).each { |i| @clusters[i] = leftover_start_vcn }
      end

      # Cache the data
      @clusters[start_vcn] = data
      (start_vcn + 1..end_vcn).each { |i| @clusters[i] = start_vcn }
    end

    def getCacheInfo(vcn)
      data = @clusters[vcn]
      offset = 0
      start_vcn = vcn
      if data.kind_of?(Integer)
        start_vcn = data
        offset = vcn - start_vcn
        data = @clusters[data]
      end

      len = data.length / @bytesPerCluster
      end_vcn = start_vcn + len - 1

      return data, start_vcn, end_vcn, len, offset
    end

    def readRawClusters(vcn, num)
      ret = []
      offset = 0

      lcns = getLCNs(vcn, num)
      lcns.each_slice(2) do |lcn, len|
        len *= @bytesPerCluster

        clusters = unless lcn.nil?
          @boot_sector.stream.seek(@boot_sector.lcn2abs(lcn))
          @boot_sector.stream.read(len)
        else
          MiqMemory.create_zero_buffer(len)
        end

        ret << clusters
        offset += len
      end

      return ret
    end

    def getLCNs(start_vcn, num)
      lcns = []
      end_vcn = start_vcn + num - 1
      vcn = start_vcn
      total_clusters = 0

      @runSpec.each_slice(2) do |lcn, len|
        total_clusters += len
        next unless total_clusters > start_vcn

        start = lcn + (vcn - (total_clusters - len))
        count = len - (start - lcn)
        count = count >= num ? num : count
        lcns << start << count

        vcn += count
        num -= count
        break if num <= 0
      end

      lcns << nil << end_vcn - vcn + 1 if vcn <= end_vcn

      return lcns
    end

		def suckBytes(buf)
			return buf[0,1].ord if buf.size == 1
			val = 0
			(buf.size - 1).downto(0) {|i| val *= 256; val += buf[i,1].ord}
			return val
		end
		
		# Return true if a particular compression unit is compressed.
		def isUnitCompr?(unit = 0)
			return false if not header.isCompressd?
			mkComprUnits if @compr_units.nil?
			@compr_units[unit].isCompressed?
		end
		
		# Organize run list into compression units.
		def mkComprUnits
			
		end

		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      out << "  Length       : #{@length}\n"
      out << "  Position     : #{@pos}\n"
			out << "  Run List     : #{@runSpec.inspect}\n"
      out << "  Cache Ranges : #{dumpCacheRanges}\n"
			out << "---\n"
			return out
		end

		def dumpRunList
			@runSpec.each_slice(2) do |lcn, len| puts "lcn = #{lcn.nil? ? 0 : lcn}, len = #{len}" end
		end

    def dumpCacheRanges
      str = k_start = k_prev = nil
      invalid = true
      out = []
      @clusters.keys.sort.each do |k|
        if @clusters[k].kind_of?(String)
          out << "#{invalid ? "*(#{str}) " : ''}#{k_start}..#{k_prev}" unless k_start.nil?
          str = k
          k_start = k
          invalid = false
        elsif @clusters[k] != str
          out << "#{invalid ? "*(#{str}) " : ''}#{k_start}..#{k_prev}" unless k_start.nil?
          str = @clusters[k]
          k_start = k
          invalid = true
        elsif k != k_prev + 1
          out << "#{k}^"
        end
        k_prev = k
      end
      out << "#{invalid ? "*(#{str}) " : ''}#{k_start}..#{k_prev}" unless k_start.nil?
      return out.inspect
    end
	end # class

end # module NTFS
