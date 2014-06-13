$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'win32/process'
require 'binary_struct'

module Process
  def self.suspend_resume_thread(thread_id, resume = true)
    hThread = OpenThread(THREAD_SUSPEND_RESUME, false, thread_id)
    if (resume)
      ResumeThread(hThread)
    else
      SuspendThread(hThread)
    end
    CloseHandle(hThread)
  end

  WIN_THREAD_ENTRY32_STRUCT = BinaryStruct.new([
    'L',			:dwSize,
    'L',			:cntUsage,
    'L',			:th32ThreadID,
    'L',			:th32OwnerProcessID,
    'L',			:tpBasePri,
    'L',			:tpDeltaPri,
    'L',			:dwFlags,
  ])
  
  def self.process_thread_list
    process_list = Hash.new {|h,k| h[k] = Array.new}

    handle = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)

    if handle == INVALID_HANDLE_VALUE
      raise Error, get_last_error
    end

    proc_entry = 0.chr * WIN_THREAD_ENTRY32_STRUCT.size
    proc_entry[0, 4] = [proc_entry.size].pack('L') # Set dwSize member

    begin
      unless Thread32First(handle, proc_entry)
        error = get_last_error
        raise Error, error
      end

      while Thread32Next(handle, proc_entry)
        data = WIN_THREAD_ENTRY32_STRUCT.decode(proc_entry)
        process_list[data[:th32OwnerProcessID]] << data[:th32ThreadID]
      end
    ensure
      CloseHandle(handle)
    end
    process_list
  end
end
