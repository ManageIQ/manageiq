require 'miq-process'

module ManageIQ::Util::MemoryLogging
  extend ActiveSupport::Concern
  include Vmdb::Logging

  def memory_logger(message, &block)
    debug(message) if block
    yield if block_given?
    debug(message)
  end

  def memory_logger_with_gc(message, &block)
    debug(message) if block
    yield if block_given?
    GC.start
    GC.start
    GC.start
    debug(message)
  end

  private

  def debug(message)
    _log.debug("#{message} -- Memory usage: #{'%.02f' % calculate_memory} MiB")
  end

  # TODO: (juliancheal) Extract this method over to MiqProcess
  def calculate_memory
    case Sys::Platform::IMPL
    when :linux
      MiqProcess.processInfo[:unique_set_size].to_f / 1.megabyte
    when :macosx
      MiqProcess.processInfo[:memory_usage].to_f / 1.megabyte
    else
      raise "Method ManageIQ::Util::MemoryLogging#memory_usage not implemented on this platform [#{Sys::Platform::IMPL}]"
    end
  end
end
