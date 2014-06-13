require Rails.root.join('lib/migration_helper')

class RemoveReserved < ActiveRecord::Migration
  include MigrationHelper::PerformancesViews

  RESERVED_CLASSES = [
    'Account',
    'AdvancedSetting',
    'AssignedServerRole',
    'AuditEvent',
    'Authentication',
    'BinaryBlob',
    'BinaryBlobPart',
    'BottleneckEvent',
    'Classification',
    'Compliance',
    'Condition',
    'Configuration',
    'CustomAttribute',
    'CustomizationSpec',
    'Disk',
    'EmsCluster',
    'EmsEvent',
    'EmsFolder',
    'EventLog',
    'ExtManagementSystem',
    'Filesystem',
    'FirewallRule',
    'GuestApplication',
    'GuestDevice',
    'Hardware',
    'Host',
    'Job',
    'Lan',
    'LifecycleEvent',
    'LogFile',
    'MiqAction',
    'MiqAlert',
    'MiqEnterprise',
    'MiqEvent',
    'MiqGroup',
    'MiqLicenseContent',
    'MiqPolicy',
    'MiqPolicyContent',
    'MiqProxy',
    'MiqQueue',
    'MiqRegion',
    'MiqReport',
    'MiqReportResult',
    'MiqSchedule',
    'MiqScsiLun',
    'MiqScsiTarget',
    'MiqSearch',
    'MiqServer',
    'MiqSet',
    'MiqTask',
    'MiqWorker',
    'Network',
    'OperatingSystem',
    'Partition',
    'Patch',
    'PolicyEvent',
    'PolicyEventContent',
    'ProxyTask',
    'RegistryItem',
    'Repository',
    'ResourcePool',
    'RssFeed',
    'ScanHistory',
    'ScanItem',
    'ServerRole',
    'Service',
    'Session',
    'Snapshot',
    'State',
    'Storage',
    'StorageFile',
    'Switch',
    'SystemService',
    'Tag',
    'Tagging',
    'TimeProfile',
    'UiTask',
    'User',
    'VimPerformance',
    'VimPerformanceState',
    'VimPerformanceTagValue',
    'Vm',
    'Volume',
    'Zone',
  ]

  # Create stub classes for all of the classes in case they don't exist in the future
  RESERVED_CLASSES.each do |c|
    klass = const_set(c, Class.new(ActiveRecord::Base))
    klass.inheritance_column = :_type_disabled  # disable STI

    MiqQueue.table_name = "miq_queue" if c == "MiqQueue"
  end
  class Reserve < ActiveRecord::Base
    self.inheritance_column = :_type_disabled  # disable STI
  end

  def up
    RESERVED_CLASSES.each do |c|
      klass = self.class.const_get(c)

      recs = klass.where("reserved IS NOT NULL").all
      if recs.length > 0
        say_with_time("Migrating reserved column for #{c}") do
          recs.each do |rec|
            Reserve.create!(
              :resource_type => rec.class.name.split("::").last,
              :resource_id   => rec.id,
              :reserved      => rec.reserved
            )
          end
        end
      end

      drop_performances_views if c == "VimPerformance"

      remove_column klass.table_name.to_sym, :reserved

      create_performances_views if c == "VimPerformance"
    end
  end

  def down
    RESERVED_CLASSES.each do |c|
      klass = self.class.const_get(c)

      drop_performances_views if c == "VimPerformance"

      add_column klass.table_name.to_sym, :reserved, :text

      create_performances_views if c == "VimPerformance"
    end
  end
end
