# encoding: US-ASCII

# TODO:
#      Provide collection of custom log names?

$:.push("#{File.dirname(__FILE__)}")

# Specifically use the Platform mod used in MiqDisk.
require 'platform'

# For message table resources.
require 'peheader'

# For registry export on MiqFS.
require 'remote-registry'

# Dev needs this.
require 'Win32API' if Platform::OS == :win32
require 'system_path_win'

require 'digest/md5'

# Common utilities.
$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'
require 'miq-unicode'
require 'miq-xml'
require 'miq-exception'

$:.push("#{File.dirname(__FILE__)}/..")
require 'event_log_filter'

class Win32EventLog

  # Standard file log names
  SYSTEM_LOGS = %w{Application System Security}
  BUFFER_READ_SIZE = 10485760  # 10 MB buffer

  # Data definitions.  (http://msdn.microsoft.com/en-gb/library/bb309024.aspx)
  ELF_LOGFILE_HEADER = BinaryStruct.new([
    'L',  :header_size,           # The size of the header structure. The size is always 0x30.
    'a4', :signature,             # The signature is always 0x654c664c, which is ASCII for eLfL.
    'L',  :majorVersion,          # The major version number of the event log. The major version number is always set to 1.
    'L',  :minorVersion,          # The minor version number of the event log. The minor version number is always set to 1.
    'L',  :start_offset,          # The offset to the oldest record in the event log.
    'L',  :end_offset,            # The offset to the ELF_EOF_RECORD in the event log.
    'L',  :current_record_number, # The number of the next record that will be added to the event log.
    'L',  :oldest_record_number,  # The number of the oldest record in the event log. For an empty file, the oldest record number is set to 0.
    'L',  :max_size,              # The maximum size, in bytes, of the event log. The maximum size is defined when the event log is created.
                                  # The event-logging service does not typically update this value, it relies on the registry configuration.
                                  # The reader of the event log can use normal file APIs to determine the size of the file.
    'L',  :flags,                 # See ELF_ below.
    'L',  :retention,             # The retention value of the file when it is created.
                                  # The event-logging service does not typically update this value, it relies on the registry configuration.
                                  # For more information about registry configuration values, see Eventlog Key.
    'L',  :end_header_size        # The ending size of the header structure. The size is always 0x30.
  ])

  # Event Log header flags.
  ELF_DIRTY        = 0x00000001   # If set, don't rely on other values in the header.
  ELF_WRAPPED      = 0x00000002   # Indicates the log is wrapped.
  ELF_LOGFULL      = 0x00000004   # Set if log full (extended implications in EventLogFormat.txt).
  ELF_LOGFILE_ARCHIVE_SET = 0x00000008   # Indicates that the archive attribute has been set for the file.
                                  # Normal file APIs can also be used to determine the value of this flag.

  # Data definitions.  (http://msdn.microsoft.com/en-gb/library/bb309022(VS.85).aspx )
  EVENTLOGEOF = BinaryStruct.new([
    'L',   :record_size_beginning,# The beginning size of the ELF_EOF_RECORD. The beginning size is always 0x28.
    'a16', :magic,                # Always \001\001\001\001\002\002\002\002\003\003\003\003\004\004\004\004
    'L',   :begin_record,         # The offset to the oldest record. If the event log is empty, this is set to the start of this structure.
    'L',   :end_record,           # The offset to the start of this structure.
    'L',   :current_record_number,# The record number of the next event that will be written to the event log.
    'L',   :oldest_record_number, # The record number of the oldest record in the event log. The record number will be 0 if the event log is empty.
    'L',   :record_size_end       # The ending size of the ELF_EOF_RECORD. The ending size is always 0x28.
  ])

  # Data definitions.  (http://msdn.microsoft.com/en-gb/library/aa363646(VS.85).aspx)
  EVENTRECORD = BinaryStruct.new([
    'L',  :record_length,         # The size of this event record, in bytes. Note that this value is stored at both ends
                                  # of the entry to ease moving forward or backward through the log. The length includes
                                  # any pad bytes inserted at the end of the record for DWORD alignment.
    'a4', :magic,                 # A DWORD value that is always set to ELF_LOG_SIGNATURE (the value is 0x654c664c), which is ASCII for eLfL.
    'L',  :record_num,            # The number of the record.
    'L',  :generated,             # The time at which this entry was submitted. This time is measured in the number of seconds elapsed since 00:00:00 January 1, 1970, Universal Coordinated Time.
    'L',  :written,               # The time at which this entry was received by the service to be written to the log. This time is measured in the number of seconds elapsed since 00:00:00 January 1, 1970, Universal Coordinated Time.
    'L',  :event_id,              # The event identifier. The value is specific to the event source for the event, and is used with source name to locate a description string in the message file for the event source
    'S',  :level,                 # See EVENTLOG_ below.
    'S',  :num_strings,           # The number of strings present in the log (at the position indicated by StringOffset). These strings are merged into the message before it is displayed to the user.
    'S',  :category,              # The category for this event. The meaning of this value depends on the event source.
    'S',  :reserved_flags,        # Reserved.
    'L',  :closing_rec_num,       # Reserved.
    'L',  :string_offset,         # Offset from beginning of record to UTF-16 strings.
    'L',  :user_sid_length,       # The size of the UserSid member, in bytes. This value can be zero if no security identifier was provided.
    'L',  :user_sid_offset,       # Offset from beginning of record.
    'L',  :data_length,           # Length of parameter data (0 if none).
    'L',  :data_offset,           # The offset of the event-specific information within this event log record, in bytes.
                                  # This information could be something specific (a disk driver might log the number of retries, for example),
                                  # followed by binary information specific to the event being logged and to the source that generated the entry.
  ])

  EVENTRECORDLENGTH = BinaryStruct.new([
  'L',  :record_length,         # The size of this event record, in bytes. Note that this value is stored at both ends
  ])

  # Event types.
  EVENT_TYPES = {
    0x0000 => :info,   # EVENTLOG_SUCCESS
    0x0001 => :error,  # EVENTLOG_ERROR_TYPE
    0x0002 => :warn,   # EVENTLOG_WARNING_TYPE
    0x0004 => :info,   # EVENTLOG_INFORMATION_TYPE
    0x0008 => :info,   # VENTLOG_AUDIT_SUCCESS
    0x0010 => :error,  # EVENTLOG_AUDIT_FAILURE
  }

  # Magic numbers used by log record types.
  MAGIC_HDR = "LfLe"
  MAGIC_CSR = "\x11\x11\x11\x11\x22\x22\x22\x22\x33\x33\x33\x33\x44\x44\x44\x44"

  # Registry constants.
  HKLM      = 0x80000002
  KEY_READ  = 0x00020019
  REG_MULTI_SZ  = 7

  # Key name buffer size.
  SIZE_BUF = 256

  # Misc Windows constants.
  INVALID_HANDLE_VALUE   = -1
  ERROR_SUCCESS          = 0
  ERROR_NO_MORE_ITEMS    = 259

  # Lookup object for translating the common %? sequences in the messages
  FORMAT_TR = Hash.new { |h, k| k }.merge(
    '% ' => " ",
    '%b' => " ",
    '%.' => ".",
    '%!' => "!",
    '%n' => "\r\n",
    '%r' => "\r",
    '%t' => "\t",
    '%0' => "",
    '!s!' => ""
  )

  # Keys that will be in the final node record
  NODE_REC_KEYS = [:generated, :event_id, :level, :category, :computer_name, :source, :message]

  attr_reader :xmlDoc, :customFileName
  attr_reader :readTimes

  def initialize(vmMiqFs = nil)
    # vmMiqFs is an MiqFS instance for the file system
    # of the guest vm if guest logs or nil if host logs.

    # If an MiqFS instance was not passed, then the OS has to be (or emulate) Win32.
    # If an MiqFS instance *was* passed, then if the guest OS is not Windows then getSystemRoot will throw.
    raise "#{self.class}::initialize: Platform is not Windows and file system is not MiqFS: cannot continue" if Platform::OS != :win32 and !vmMiqFs.class.to_s.include?('Miq')

    # Get a file system instance if we don't already have one.
    @fs = vmMiqFs
    @fs = File if @fs.nil?

    # Init times.
    @readTimes = {}

    @msgtbl_cache = {}

    # Get root, system message tables & init messagetable cache.
    if @fs == File
      @systemRoot = 'c:/windows/system32'
      @kernel32_fn = 'c:/windows/system32/kernel32.dll'
    else
      @systemRoot = Win32::SystemPath.systemRoot(@fs)
      @kernel32_fn = "#{Win32::SystemPath.system32Path(@fs, @systemRoot)}/kernel32.dll"
    end
  end

  def readAllLogs(options)
    options = options.collect { |l| {:name => l, :filter => nil} } if options[0].kind_of?(String)

    options.each do |o|
      start = Time.now
      readLog(o[:name], o[:filter])
      @readTimes[o[:name]] = Time.now - start
    end
    return @xmlDoc
  end

  def readLog(log, filter = nil)
    filter ||= {}
    EventLogFilter.prepare_filter!(filter)

    # Get message source files.  (This also caches the event log registry entries.)
    sources = getEventSourceMessageFiles(log)
    @f = @buf = nil


    # Get event log file and validate it is a format we support
    event_file = mkLogPath(log)
    unless File.extname(event_file).downcase == ".evt"
      raise MiqException::NtEventLogFormat, "#{self.class}: Unsupported Win32 Eventlog format [#{File.extname(event_file)}] for event log [#{log}].  File:[#{event_file}]"
    end

    # Start an XML document
    recordsNode = mkXmlDoc(log, event_file)

    getFileObj(event_file) do |f, filename|
      st = Time.now
      $log.info "#{self.class}: Opening file for [#{log}]" if $log
      @f = f
      @offset = BUFFER_READ_SIZE * -1
      
      hdr = ELF_LOGFILE_HEADER.decode(read_buffer(0,ELF_LOGFILE_HEADER.size))
      hdr[:wrapped] = !(hdr[:flags] & ELF_WRAPPED).zero?
      @file_size = @fs == File ? File.size(filename) : @fs.fileSize(filename)

      $log.info "#{self.class}: Opened file for [#{log}] in [#{Time.now-st}] seconds.  Data Size:[#{@file_size}]  Wrapped:[#{hdr[:wrapped]}]" if $log

      parse_time = Time.now
      recs_found = 0
      recs_processed = 0
      @dup_check = {}

      each_record(hdr, log) do |rec|
        recs_processed += 1
        
        # Get log record components & filter on them
        rec[:generated] = Time.at(rec[:generated]).utc.iso8601
        break if EventLogFilter.filter_by_generated?(rec[:generated], filter)

        rec[:level] = EVENT_TYPES[rec[:level]]
        next if EventLogFilter.filter_by_level?(rec[:level], filter)

        getSourceName(rec)
        next if EventLogFilter.filter_by_source?(rec[:source], filter)

        getStrings(rec)
        getMessage(log, rec, sources)
        next if EventLogFilter.filter_by_message?(rec[:message], filter)

        # Get the rest of the record components
        getComputerName(rec)
        # There are not presently being used, so there is no need to collect them
        #rec[:written] = Time.at(rec[:written]).utc.iso8601
        #getSID(buf, pos, rec)
        #getData(buf, pos, rec)

        # Add the node to the XML
        recs_found += 1 if addNodeRec(recordsNode, rec)

        # Quit if we've found enough records
        break if EventLogFilter.filter_by_rec_count?(recs_found, filter)
      end

      # Clean up
      @dup_check = nil

      # Store based on log.
      recordsNode.add_attribute(:num_records, recs_found)

      $log.info "#{self.class}: Parsed [#{recs_processed}] [#{log}] records in [#{Time.now-parse_time}] seconds.  Collected [#{recs_found}] records.  Total time [#{Time.now-st}] seconds." if $log
    end
    @f = nil
  end

  private

  def mkLogPath(log)
    unless @reg_source_xml.nil?
      appKey = XmlFind.findElement("CurrentControlSet/Services/Eventlog/#{log}/File", @reg_source_xml)
      logPath = appKey.text
    else
      logPath = Win32::SystemPath.registryPath(@fs, @systemRoot) + "/"
      logPath = case log
      when 'Application'  then logPath + "appevent.evt"
      when 'Security'     then logPath + "secevent.evt"
      when 'System'       then logPath + "sysevent.evt"
      else
        raise "#{self.class}::mkLogPath: '#{log}' is not a path to an event log file." unless log.class.to_s == "String"
        raise "#{self.class}::mkLogPath: File not found: '#{log}'" if !isFile?(log)
        @customFileName = log
      end
    end
    return logPath
  end

  # These functions hide the differences for equivalent calls in the file instance.
  def isFile?(fn)
    meth = @fs.respond_to?(:fileExists?) ? :fileExists? : :exists?
    return @fs.send(meth, fn)
  end

  def getFileObj(fn)
    # Determine what file open method to use
    meth = @fs.respond_to?(:fileOpen) ? :fileOpen : :open
    fn = fn.gsub('\\','/')
    f = @fs.send(meth, fn, "rb")

    #If we are passed a block, run it and close the file handle
    return f unless block_given?
    begin
      yield(f, fn)
    ensure
      f.close rescue nil
    end
  end
  
  def mkXmlDoc(log, event_file)
    @xmlDoc ||= XmlHash.createDoc("<event_log/>")
    return @xmlDoc.root.add_element(:log, {:name => log, :path => event_file})
  end

  # This function finds the first event record in the buffer.
  def getFirstRecordOffset(hdr)
    # Find the cursor record and get first rec from there.
    # hdr[:end_offset] should point to the offset of the EOF record.  If the dirty flag
    # is set this is likely to have moved, but should be in front of it, so start the search there.
    pos = findCursorRecord(hdr[:end_offset])
    pos = findCursorRecord(0) if pos.nil?
    raise "Win32 Eventlog cursor record not found." if pos.nil?

    return EVENTLOGEOF.decode(read_buffer(pos-4, EVENTLOGEOF.size))
  end

  # The last 4 bytes of a record hold the record length for that record.
  # Grab it and set the new position to the top of that record.
  def getNextRecordOffset(curr_pos, hdr)
    # Called the first time
    if curr_pos.nil?
      @csr = getFirstRecordOffset(hdr)
      curr_pos = @csr[:end_record]
    end

    # Check for wrapped messages
    if curr_pos == ELF_LOGFILE_HEADER.size
      curr_pos = findEndBuffer()
    end

    offset = curr_pos-4
    prev_rec_length = read_buffer(offset, 4, -1)
    rec_len = EVENTRECORDLENGTH.decode(prev_rec_length)[:record_length]
    new_pos = (curr_pos-rec_len)

    # Check for wrapped messages
    if new_pos < ELF_LOGFILE_HEADER.size
      copy_from_end = ELF_LOGFILE_HEADER.size - new_pos
      new_pos = @file_size - copy_from_end
    end
    return new_pos
  end

  # If the record header cannot fit at the end of the file when the log file wraps
  # the end of the file is padded with 0x27 markers after the record length.  So
  # walk backwards until a non-0x27 marker is found.
  def findEndBuffer()
    offset = @file_size - 4
    while EVENTRECORDLENGTH.decode(read_buffer(offset, 4,-1))[:record_length] == 0x27
      offset -= 4
    end
    return offset + 4
  end

  def findCursorRecord(search_offset)
    pos = nil
    while pos==nil
      pos = read_buffer(search_offset, BUFFER_READ_SIZE).index(MAGIC_CSR)
      search_offset += BUFFER_READ_SIZE if pos.nil?
      break if search_offset >= @file_size
    end
    pos += search_offset unless pos.nil?
    return pos
  end

  def each_record(hdr, log)
    # Check for an empty event log file
    return if hdr[:oldest_record_number].zero?

    last_pos = pos = getNextRecordOffset(nil, hdr)
    
    loop do
      # Get this record.
      rec = EVENTRECORD.decode(read_buffer(pos, EVENTRECORD.size, -1))

      # If record wraps around to the start of the buffer
      if pos + rec[:record_length] > @file_size

        # If we get to the end of the file make sure the event log is marked as wrapped
        # before trying to process data from the begin of the file.
        break if (hdr[:flags] & ELF_WRAPPED).zero?

        # If the record header fits then in the remaining bytes the header
        # and data is written upto the end of the file.  The remaining data
        # is writting at the top of the file after the file header.
        remaining_bytes = @file_size - pos
        wrapped_byte_count = rec[:record_length] - remaining_bytes
        wrapped_bytes = read_buffer(ELF_LOGFILE_HEADER.size, wrapped_byte_count)
        read_buffer(pos, rec[:record_length], -1)
        @buf << wrapped_bytes
      end

      # Verify record synchronization.
      if rec[:magic] != MAGIC_HDR
        csr = EVENTLOGEOF.decode(read_buffer(pos, EVENTLOGEOF.size))
        break if csr[:magic] == MAGIC_CSR
        # Check if the Cursor record appears anywhere in the buffer data for this mis-aligned record.
        break unless read_buffer(pos, last_pos-pos).index(MAGIC_CSR).nil?
        # When the log is wrapped if we find a mis-aligned record it is on the cursor record missing, likely due
        # to the log actively being updated when we read it.
        break if hdr[:wrapped] == true

        if $log
          $log.error "MIQ(#{self.class}-readLog) Log synchronization for {#{log}} is broken - rec:[#{rec.inspect}] csr:[#{csr.inspect}] header:[#{hdr.inspect}] pos:[#{pos}] buf length:[#{@buf.length}]"
          $log.error "MIQ(#{self.class}-readLog)   4K buf <  pos:"
          read_buffer((pos < 4096 ? 0 : pos - 4096), 4096).hex_dump(:obj => $log, :meth => :error, :newline => false)
          $log.error "MIQ(#{self.class}-readLog)   4K buf >= pos:"
          read_buffer(pos, 4096).hex_dump(:obj => $log, :meth => :error, :newline => false)
        end
        raise "MIQ(#{self.class}-readLog) Log synchronization is broken."
      end

      rec[:data] = read_buffer(pos, rec[:record_length], -1)
      yield(rec)

      break if rec[:record_num] == @csr[:oldest_record_number]

      last_pos = pos
      pos = getNextRecordOffset(pos, hdr)
    end
  end

  def read_buffer(offset, length, direction=1)
    #puts "[#{@offset}] -- [#{@offset+BUFFER_READ_SIZE}], O:[#{offset}] L:[#{length}]"
    if (offset < @offset) || (offset+length > @offset+BUFFER_READ_SIZE)
      read_offset = offset
      if direction < 0
        # When adjusting the read offset backwards account for the length of the data
        # being read plus an extra 4K which should cover the data portion of a record
        # since we have to read the record header ahead of the data.
        read_offset = offset - BUFFER_READ_SIZE + length + 4096
        read_offset = 0 if read_offset < 0
      end
      #puts "***Loading from offset [#{read_offset}]"
      @f.seek(read_offset)
      @buf = @f.read(BUFFER_READ_SIZE)
      @offset = read_offset
    end

    return @buf[offset-@offset, length]
  end

  def getSourceName(rec)
    str = rec[:data][EVENTRECORD.size..-1]
    if str
      str = weirdFixString(str)
      str.UnicodeToUtf8!
      rec[:source] = str
    end
  end

  def getComputerName(rec)
    str = rec[:data][(EVENTRECORD.size + rec[:source].length * 2 + 2)..-1]
    if str
      str = weirdFixString(str)
      str.UnicodeToUtf8!
      rec[:computer_name] = str
    end
  end

  def getSID(buf, pos, rec)
    if rec[:user_sid_length] > 0
      rec[:user_sid] = decodeSid(buf[pos + rec[:user_sid_offset], rec[:user_sid_length]])
    end
  end

  def decodeSid(data)
    sid = "S-"
    # BYTE Revision
    sid << data[0].to_s << "-"
    # BYTE SubAuthorityCount
    subCount = data[1]
    # WORD Authority[3]
    0.upto(2) {|i|
      auth = data[2 + i * 2, 2].unpack('n')[0]
      sid << auth.to_s << "-" if auth != 0
    }
    # DWORD SubAuthority[*]
    0.upto(subCount - 1) {|i|
      subAuth = data[8 + i * 4, 4].unpack('L')[0]
      sid << subAuth.to_s << "-"
    }
    sid.chop!
    return sid
  end

  def getStrings(rec)
    rec[:strings] = []
    return if rec[:num_strings] <= 0

    offset = rec[:string_offset]
    (rec[:num_strings] - 1).times do
      str = rec[:data][offset..-1]
      if str
        str = weirdFixString(str)
        # Compensate for nil strings.
        if str == "\000"
          rec[:strings] << ""
          offset += 2
        else
          offset += str.length + 2
          rec[:strings] << str.UnicodeToUtf8!
        end
      end
    end
  end

  def getData(buf, pos, rec)
    if rec[:data_length] > 0
      rec[:data] = buf[pos + rec[:data_offset], rec[:data_length]]
    end
  end

  # The standard conversion doesn't terminate a string at \000\000 so use this.
  def weirdFixString(str)
    idx = str.index("\000\000")
    return idx.nil? ? str : str[0..idx]
  end

  def addNodeRec(node, rec)
    node_rec = {}

    # Put the needed fields in the node_rec, and collect them for md5 hashing to
    #   verify that this record is unique
    md5 = NODE_REC_KEYS.collect { |k| node_rec[k] = rec[k] }.join(' ')
    md5 = Digest::MD5.hexdigest(md5)
    return false if @dup_check.has_key?(md5)
    @dup_check[md5] = nil

    node_rec[:uid] = md5

    node.add_element(:record, node_rec)
    return true
  end

  # Given a record, turn it's event id into a log message.
  def getMessage(log, rec, sources)
    src = rec[:source].downcase
    unless sources[:message].has_key?(src)
      # TODO: Use the Windows message from els.dll
      rec[:message] = "#{self.class}::getMessage: The source '#{rec[:source]}' is not listed under HKLM\\System\\CurrentControlSet\\Services\\EventLog\\#{log}"
      return
    end

    msgfiles = sources[:message][src].split(";")
    paramfiles = sources[:param][src].split(";") if sources[:param].has_key?(src)

    msg = errMsg = nil
    id = rec[:event_id]

    msgfiles.each do |fn|
      msgtbls = getMessageTables(fn)
      unless msgtbls.kind_of?(Hash)
        errMsg ||= ""
        errMsg << "#{msgtbls}\n"
        next
      end

      str = getString(id, msgtbls)
      next if str.nil?
      fmtSub(str)

      msg = str.dup
      strSub(msg, rec, msgtbls, paramfiles)
      break
    end

    msg = errMsg.nil? ? "#{self.class}::getMessage: Couldn't find message id in any listed source" : errMsg if msg.nil?
    
    rec[:message] = msg.chomp!
  end

  def getParamMessage(id, paramfiles)
    return "" if paramfiles.nil?

    paramfiles.each do |fn|
      msgtbls = getMessageTables(fn)
      return "" unless msgtbls.kind_of?(Hash)

      str = getString(id, msgtbls)
      return str.dup unless str.nil?
    end

    return ""
  end

  # Search for id in messagetables.
  def getString(id, msgtbls)
    return msgtbls unless msgtbls.kind_of?(Hash)
    return msgtbls[id]
  end

  def getMessageTables(fn)
    # Check cache for this file's messagetables.
    return @msgtbl_cache[fn] if @msgtbl_cache.has_key?(fn)

    # Get file & read messagetable resources.
    peh = nil
    begin
      getFileObj(fn) do |f, fn2|
        begin
          peh = PEheader.new(f)
          # Stick this table in the cache.
          @msgtbl_cache[fn] = peh.messagetables
        rescue
          @msgtbl_cache[fn] = "#{self.class}::getMessageTables: Invalid message table in file: #{fn}"
        end
      end
    rescue
      @msgtbl_cache[fn] = "#{self.class}::getMessageTables: File not found: #{fn}"
    end

    return @msgtbl_cache[fn]
  end

  def fmtSub(msg)
    msg.gsub!(/%[b\.!nrt0]|!s!/) { |s| FORMAT_TR[s] }
  end

  # String substitution for Win32 FormatMessage (%1, %2 & so on).
  def strSub(msg, rec, msgtbls, paramfiles)
    # Replace occurances of %%n[n...] with the value from the parameter message file
    # Replace occurances of %n[n...] with (in this order):
    #   1. A string from the record's Strings array.
    #   2. A string from a messagetable whose id is n[n...]
    #   3. A string from the system messagetable whose id is n[n...]
    msg.gsub!(/(%%?)([1-9][0-9]*)/) do
      percents, id = $1, $2.to_i

      if percents.length == 1
        param = rec[:strings][id - 1] if id <= rec[:strings].size
        param = getString(id, msgtbls) if param.nil?
        param = getString(id, getMessageTables(@kernel32_fn)) if param.nil?
      else
        param = getParamMessage(id, paramfiles)
      end
      param = "NO PARAM: #{id}" if param.nil?

      param
    end
  end

  # Given a log name, get event sources & message files in a hash.
  def getEventSourceMessageFiles(log)
    return getSourcesFromMiqFS(log) if Object.const_defined?(:MiqFS) && @fs.kind_of?(MiqFS)
    return getSourcesFromWin32(log)
  end

  def getSourcesFromMiqFS(log)
    # Initialize the message source hash object
    sources = {:message => {}, :param => {}, :category => {}}

    # Load registry section where we find the NT event log message source files.
    if @reg_source_xml.nil?
      reg = RemoteRegistry.new(@fs, true)
      @reg_source_xml = reg.loadHive("system", [{:key=>'CurrentControlSet/Services/Eventlog',:value=>['CategoryMessageFile','EventMessageFile','ParameterMessageFile','File']}])
    end

    appKey = XmlFind.findElement("CurrentControlSet/Services/Eventlog/#{log}", @reg_source_xml)
    appKey.each_element(:key) do |src|
      keyName = src.attributes[:keyname].downcase

      [['EventMessageFile', :message],
        ['ParameterMessageFile', :param],
        ['CategoryMessageFile', :category]].each do |msg_file, type|
        src.each_element_with_attribute(:name, msg_file) do |e|
          fn = e.text.to_s
          fn.gsub!(/%SystemRoot%/i, @systemRoot)
          sources[type][keyName] = fn
        end
      end
    end
    return sources
  end

  def getSourcesFromWin32(log)
    require 'win32/registry'
    sources = {:message => {}, :param => {}, :category => {}}
    types = {'EventMessageFile'=>sources[:message], 'ParameterMessageFile'=>sources[:param], 'CategoryMessageFile'=> sources[:category]}
    src = "system\\currentcontrolset\\services\\eventlog\\#{log}"
    
    Win32::Registry::HKEY_LOCAL_MACHINE.open(src) do |reg|
      reg.each_key do |subKey, wtime|
        subpath = "#{src}\\#{subKey}"
        subKey.downcase!
        Win32::Registry::HKEY_LOCAL_MACHINE.open(subpath) do |reg|
          reg.each_value do |name, type, data|
            case name
            when 'EventMessageFile', 'ParameterMessageFile', 'CategoryMessageFile' then
              fn = data.to_s
              fn.gsub!(/%SystemRoot%/i, @systemRoot)
              types[name][subKey] = fn
            end
          end
        end
      end
    end
    return sources
  end

  def getEvtMsgFile(hKey)
    buf = ""
    len = [0].pack('L')
    type = [0].pack('L')
    res = @@RegQueryValueEx.call(hKey, "EventMessageFile", 0, type, buf, len)
    # Beware: this MAY come up at some point.
    raise "#{self.class}::getEvtMsgFile: Got REG_MULTI_SZ" if type.unpack('L')[0] == REG_MULTI_SZ

    len = len.unpack('L')[0]
    buf = " " * len
    len = [len].pack('L')

    res = @@RegQueryValueEx.call(hKey, "EventMessageFile", 0, type, buf, len)
    if res != ERROR_SUCCESS then
      buf = ""
      len = [0].pack('L')
    end
    return buf, len
  end

  def fixFileList(buf, len)
    buf = buf[0...(len.unpack('L')[0] - 1)]
    buf = buf.split("\\").join("/")
    buf.gsub!(/%SystemRoot%/i, @systemRoot)
    return buf
  end
end

# If invoked from command line.
if __FILE__ == $0
  puts "Reading logs..."
  start = Time.now
  log = Win32EventLog.new

  filter = {:level=> :warn}
  log.readLog("Application", filter)
  log.readLog("Security", filter)
  log.readLog("System", filter)

  puts "Read logs completed in #{Time.now - start} seconds"
end
