# This is a modified version of the core_ext patches to Kernel::require, originally
# authored by Richard Schneeman (@schneems):
#
#   https://github.com/schneems/derailed_benchmarks/blob/2a736e1/lib/derailed_benchmarks/require_tree.rb
#
# No current license exists.

require 'bigdecimal'
require 'sys/proctable'
require 'English'
require_relative 'require_tree'

ENV['CUT_OFF'] ||= "0.3"

# This file contains classes and monkey patches to measure the amount of memory
# useage requiring an individual file adds.

# Monkey patch kernel to ensure that all `require` calls call the same
# method
module Kernel
  alias original_require require

  MB_BYTES = ::BigDecimal.new(1_048_576)
  if ENV["CI"] && ENV["TRAVIS"]
    # Travis doesn't seem to like Sys::ProcTable very much... this is the work
    # around for now until we can get that worked out.
    CONVERSION       = {"kb" => 1024, "mb" => 1_048_576, "gb" => 1_073_741_824}.freeze
    PROC_STATUS_FILE = Pathname.new("/proc/#{$PID}/status").freeze
    VMRSS_GREP_EXP   = /^VmRSS/
    MEMORY_MB_PROC = proc do
      begin
        rss_line = PROC_STATUS_FILE.each_line.grep(VMRSS_GREP_EXP).first
        return unless rss_line
        return unless (_name, value, unit = rss_line.split(nil)).length == 3
        (CONVERSION[unit.downcase!] * ::BigDecimal.new(value)) / MB_BYTES
      rescue Errno::EACCES, Errno::ENOENT
        0
      end
    end
  else
    MEMORY_MB_PROC = proc { (Sys::ProcTable.ps($PID).rss / MB_BYTES).to_f }
  end

  def require(file)
    Kernel.require(file)
  end

  # This breaks things, not sure how to fix
  # def require_relative(file)
  #   Kernel.require_relative(file)
  # end
  class << self
    attr_writer :require_stack
    alias original_require require
    # alias :original_require_relative :require_relative

    def require_stack
      @require_stack ||= []
    end
  end

  # The core extension we use to measure require time of all requires
  # When a file is required we create a tree node with its file name.
  # We then push it onto a stack, this is because requiring a file can
  # require other files before it is finished.
  #
  # When a child file is required, a tree node is created and the child file
  # is pushed onto the parents tree. We then repeat the process as child
  # files may require additional files.
  #
  # When a require returns we remove it from the require stack so we don't
  # accidentally push additional children nodes to it. We then store the
  # memory cost of the require in the tree node.
  def self.measure_memory_impact(file, &block)
    node   = MiqBenchmark::RequireTree.new(file)

    parent = require_stack.last
    parent << node
    require_stack.push(node)
    begin
      before = ::Kernel::MEMORY_MB_PROC.call
      block.call file
    ensure
      require_stack.pop # node
      after = ::Kernel::MEMORY_MB_PROC.call
    end
    node.cost = after - before
  end
end

# Top level node that will store all require information for the entire app
TOP_REQUIRE = MiqBenchmark::RequireTree.new("TOP")
::Kernel.require_stack.push(TOP_REQUIRE)

Kernel.define_singleton_method(:require) do |file|
  measure_memory_impact(file) { |f| original_require(f) }
end

# Don't forget to assign a cost to the top level
# cost_before_requiring_anything = GetProcessMem.new.mb
cost_before_requiring_anything = ::Kernel::MEMORY_MB_PROC.call
TOP_REQUIRE.cost = cost_before_requiring_anything
def TOP_REQUIRE.set_top_require_cost
  self.cost = ::Kernel::MEMORY_MB_PROC.call - cost
end
