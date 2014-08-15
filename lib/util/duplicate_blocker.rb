#
# DuplicateBlocker wraps a call to a given service and may block the calls
# when too many duplicate ones are made in a short period of time.
#
# The default implementation considers a call duplicated if its method name
# and arguments are the same as an earlier method call. However the user can override
# the definition of duplication by providing a block to generate a key to identify the call.
#
# Initially all method calls are allowed to go through. When duplicated calls within a
# time window reaches a threshold, any further duplicated call is blocked. The calls are back
# to normal as soon as the duplicates within the window drop below the threshold.
#
# A time window is divided into many slots. A slot is the finest time unit in this algorithm.
# Both the time window and the slot width are configurable.
#
# By default a DuplicateFoundExecption is thrown when a call is blocked. However
# the call only returns nil if throw_exception_when_blocked flag is turned off.
#
# A message is logged when the counter increments every configurable number or
# when the counter get reset.
#
# require 'duplicate_blocker'
# class TestService
#
#   include DuplicateBlocker
#
#   # Optional
#   dedup_handler_class MyCustomDedupHandler
#
#   # Optional
#   dedup_handler do |handler|
#     handler.logger = Logger.new(STDOUT)
#     handler.duplicate_threshold = 120
#     handler.duplicate_window = 60
#     handler.window_slot_width = 0.1
#     handler.progress_threshold = 500
#     handler.throw_exception_when_blocked = true
#     handler.key_generator = proc { |meth, *args| ... } # return a key based on method and arguments
#     handler.descriptor = proc { |meth, *args| ... } # return a description string
#   end
#
#   def instance_service() ...
#   def self.class_service() ...
#
#   dedup_instance_method :instance_service  # register instance methods to hijack
#   dedup_class_method :class_service        # register class methods to hijack
# end
#
# Duplicate block was inspired from GitHub project https://github.com/wsargent/circuit_breaker
# Particularly module DuplicateBlocker was modified from original module CircuitBreaker.
#
# Original copyright:
#
# Copyright 2009 Will Sargent
# Author: Will Sargent <will.sargent@gmail.com>
# Many thanks to Devin Mullins
#
require 'active_support/concern'

module DuplicateBlocker
  extend ActiveSupport::Concern

  module ClassMethods
    #
    # Takes a splat of method names, and wraps them with the dedup_handler.
    #
    def dedup_instance_method(*methods)
      dedup_handler = self.dedup_handler

      methods.each do |meth|
        m = instance_method meth
        define_method meth do |*args|
          dedup_handler.handle m.bind(self), *args
        end
      end
    end

    def dedup_class_method(*methods)
      dedup_handler = self.dedup_handler

      methods.each do |meth|
        m = method(meth).unbind
        define_singleton_method meth do |*args|
          dedup_handler.handle m.bind(self), *args
        end
      end
    end

    #
    # Returns dedup_handler.  Yields the instance back when passed a block.
    #
    def dedup_handler(&_block)
      @dedup_handler ||= dedup_handler_class.new

      yield @dedup_handler if block_given?

      @dedup_handler
    end

    #
    # Allows you to define a custom dedup_handler instead of DuplicateBlocker::DedupHandler
    #
    def dedup_handler_class(klass = nil)
      @dedup_handler_class ||= (klass || DedupHandler)
    end
  end
end

require 'util/duplicate_blocker/dedup_handler'
require 'util/duplicate_blocker/duplicate_found_exception'
