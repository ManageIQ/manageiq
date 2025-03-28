#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

# TODO: to test, delete some toplevel rows via delete_all, forcing orphans:
# Container.all.limit(100).delete_all
# ContainerGroup.all.limit(100).delete_all
# MiqRequest.all.limit(10).delete_all

def purge_by_orphaned(klass, fk, window)
  klass.include PurgingMixin
  klass.define_method(:purge_method) { :destroy }
  klass.purge_by_orphaned(fk, window).tap {|total| puts "Purged: #{klass}: #{total}"}
end

classes_to_purge = [
  ContainerCondition, :container_entity, 1000,
  ContainerVolume, :parent, 1000,
  CustomAttribute, :resource, 1000,
  SecurityContext, :resource, 1000,
  RequestLog, :resource, 500,
  ContainerEnvVar, :container, 1000,
  ContainerPortConfig, :container, 1000,
  MiqReportResultDetail, :miq_report_result, 1000,
  BinaryBlob, :resource, 1000
]

_result, bm = Benchmark.realtime_block("TotalTime") do
  classes_to_purge.each_slice(3) do |klass, fk, window|
    Benchmark.realtime_block(klass.name) do
      purge_by_orphaned(klass, fk, window)
    end
  end
  nil
end
pp bm
