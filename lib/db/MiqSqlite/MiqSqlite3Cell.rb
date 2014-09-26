# encoding: US-ASCII

require 'ostruct'
require 'enumerator'

require 'binary_struct'
require_relative 'MiqSqlite3Util'
require_relative 'MiqSqlite3Page'


module MiqSqlite3DB
  class MiqSqlite3Cell
    
    attr_accessor :left_child, :key, :data, :pointer
    
    def initialize(page, pointer)
      @page    = page
      @pointer = pointer
      @data = @key = @left_child = @fields = nil

      offset = nData = 0
      if !@page.leaf
        @left_child = @page.buf[@pointer+offset,4].unpack('N')[0]
        offset += 4
      end

      if @page.hasData
        nData, count = MiqSqlite3DB.variableInteger(@page.buf[@pointer+offset,9])
        offset += count
      end

      nKey, count = MiqSqlite3DB.variableInteger(@page.buf[@pointer+offset,9])
      offset += count
      if @page.intKey
        @key = nKey
        nKey = 0
      end
      
      getPayload(nData, nKey, offset)
    end
    
    def fields
      return @fields if @fields
      
      return nil if @data.nil?
      len     = @data[0]
      @fields = Array.new
      offset   = len
      byte     = 1
      while byte < len
        val, count  = MiqSqlite3DB.variableInteger(@data[byte..-1])
        byte += count
        flen, type = decodeField(val)
        
        field = Hash.new
        if flen == 0
          if type == 'null'
            field['type'] = 'text'
            field['data'] = nil    
          else
            field['type'] = 'boolean'
            field['data'] = true   if type == 'true'
            field['data'] = false  if type == 'false'
          end
        else
          field['len']  = flen
          field['type'] = type
          fdata = @data[offset,flen]
          offset += flen
          if type == 'integer'
            fdata = "\x00".concat(fdata) if flen == 3
            field['data'] = fdata.unpack("C")[0]  if flen == 1
            field['data'] = fdata.unpack("n")[0]  if flen == 2
            field['data'] = fdata.unpack("N")[0]  if flen == 3 || flen == 4
          else
            field['data'] = fdata
          end  
        end
        @fields << field
      end
      return @fields
    end
    
    def dump
		  puts "======== Dumping Cell ========="
		  puts "Page:                            #{@page.pagenum}"
		  puts "Cell:                            #{@pointer}"
		  puts "Left Child:                      #{@left_child}" if @left_child
		  puts "Key:                             #{@key}"        if @key
		  puts "Data:                            #{@data}"       if @data
		  puts "Data Length:                     #{@data.size}"  if @data
		  fields.each { |f|
		    p f
	    }
    end
    
    private
    
    def getPayload(nData, nKey, offset)
      nPayload = nData + nKey
      if nPayload <= @page.maxLocal
        ## This is the (easy) common case where the entire payload fits
        ## on the local page.  No overflow is required.
        nLocal = nPayload
        iOverflow = 0
        nSize = nPayload + offset   # Total size of cell content in bytes
        nSize = 4 if nSize < 4      # Minimum cell size is 4
        @data = @page.buf[@pointer+offset,      nData] if nData > 0
        @key  = @page.buf[@pointer+offset+nData,nKey]  if nKey > 0
      else
        ## If the payload will not fit completely on the local page, we have
        ## to decide how much to store locally and how much to spill onto
        ## overflow pages.  The strategy is to minimize the amount of unused
        ## space on overflow pages while keeping the amount of local storage
        ## in between minLocal and maxLocal.
        ##
        ## Warning:  changing the way overflow payload is distributed in any
        ## way will result in an incompatible file format.
        ##
        minLocal  = @page.minLocal  # Minimum amount of payload held locally
        maxLocal  = @page.maxLocal  # Maximum amount of payload held locally
        surplus   = minLocal + (nPayload - minLocal)%(@db.usableSize - 4)   # Overflow payload available for local storage
        nLocal    = (surplus <= maxLocal) ? surplus : minLocal
        iOverflow = nLocal + offset
        nSize     = iOverflow + 4
        @overflow = @page.buf[@pointer+iOverflow,4].unpack('N')[0]
raise "cell (#{@number}): PAYLOAD OVERFLOW NOT SUPPORTED"
      end

    end
    
    #** The following table describes the various storage classes for data:
    #**
    #**   serial type        bytes of data      type
    #**   --------------     ---------------    ---------------
    #**      0                     0            NULL
    #**      1                     1            signed integer
    #**      2                     2            signed integer
    #**      3                     3            signed integer
    #**      4                     4            signed integer
    #**      5                     6            signed integer
    #**      6                     8            signed integer
    #**      7                     8            IEEE float
    #**      8                     0            Integer constant 0
    #**      9                     0            Integer constant 1
    #**     10,11                               reserved for expansion
    #**    N>=12 and even       (N-12)/2        BLOB
    #**    N>=13 and odd        (N-13)/2        text
    def decodeField(serial_type)
      case serial_type
        when 0;         return 0, 'null'
        when 1;         return 1, 'integer'
        when 2;         return 2, 'integer'
        when 3;         return 3, 'integer'
        when 4;         return 4, 'integer'
        when 6;         return 6, 'integer'
        when 8;         return 8, 'integer'
        when 7;         return 8, 'float'
        when 8;         return 0, 'false'
        when 9;         return 0, 'true'
        when 10;        raise "Unknown Column Type #{serial_type}"
        when 11;        raise "Unknown Column Type #{serial_type}"
      end
      
      type = serial_type % 2 == 0 ? 'blob' : 'text'
      len  = (serial_type - 12 )/ 2
      return len, type
    end
    
    
  end
end
