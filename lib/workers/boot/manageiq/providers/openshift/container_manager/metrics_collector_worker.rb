require "miq_helper"

# FIXME: Make this not necessary
module Vmdb
end

require "vmdb/global_methods"
include Vmdb::GlobalMethods

require "active_support/core_ext/module/delegation"
require "active_support/core_ext/numeric/bytes"
require "active_record"
require "vmdb/logging"

Vmdb::Loggers.init

require "vmdb/deprecation"
require "manageiq-gems-pending"
require "util/extensions/miq-module"
require "default_value_for"

require "extensions/miq_db_config"

require "config"
Config.load_and_set_settings(Config.setting_files(Miq.root.join('config'), ::Miq.env))

require "vmdb/settings"
require "vmdb/config"
require "vmdb/plugins"

Vmdb::Settings.init
Vmdb::Loggers.apply_config(::Settings.log)

# TODO: Split this out
class ConnectionInfo
  extend MiqDbConfig

  def self.config
    database_configuration[Miq.env]
  end
end

ActiveRecord::Base.logger = Logger.new(Miq.root.join("log", "mini_miq_server.log"))
ActiveRecord::Base.establish_connection(ConnectionInfo.config)

require "extensions/ar_region"
require "extensions/ar_lock"
require "extensions/ar_nested_count_by"
require "extensions/ar_href_slug"        # Is this needed for the worker?
require "extensions/ar_to_model_hash"
require "extensions/ar_table_lock"
require "extensions/ar_taggable"         # Is this needed by the worker?
require "extensions/as_include_concern"
require "extensions/virtual_total"
require "extensions/require_nested"
require "extensions/ar_adapter/ar_dba/postgresql"

# FIXME:  Do this somewhere else, or try to not use ApplicationRecord (if possible)
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  FIXTURE_DIR = Miq.root.join("db/fixtures")

  include ArRegion
  include ArLock
  include ArNestedCountBy
  include ArHrefSlug
  include ToModelHash

  extend ArTableLock
end

require "mixins/custom_attribute_mixin"  # seems reporting related
require "mixins/new_with_type_sti_mixin"
require "mixins/tenancy_common_mixin"    # is this needed?
require "mixins/tenancy_mixin"           # is this needed?
require "mixins/availability_mixin"
require "mixins/supports_feature_mixin"
require "mixins/compliance_mixin"        # shouldn't be needed for a worker
require "mixins/filterable_mixin"        # shouldn't be needed for a worker
require "mixins/event_mixin"
require "mixins/miq_policy_mixin"
require "mixins/relationship_mixin"
require "mixins/aggregation_mixin"       # Maybe avoid this..
require "mixins/authentication_mixin"
require "mixins/async_delete_mixin"
# require "mixins/scanning_operations_mixin"
require "mixins/scanning_mixin"
require "mixins/retirement_mixin"
require "mixins/serialized_ems_ref_obj_mixin"
require "mixins/provider_object_mixin"
require "mixins/ownership_mixin"
require "mixins/process_tasks_mixin"
require "mixins/alert_mixin"
require "mixins/drift_state_mixin"
require "mixins/storage_mixin"
require "mixins/per_ems_worker_mixin"
require "mixins/per_ems_type_worker_mixin"

require "mixins/archived_mixin"
require "mixins/purging_mixin"
require "mixins/tenant_identity_mixin"

# required for MiqServer
require "mixins/configuration_management_mixin"

# required for MiqRegion
require "mixins/naming_sequence_mixin"

require "uuid_mixin"


module ManageIQ
  module Providers
    # TODO:  Make the manageiq-providers-openshift gem do this (all provider gems really)
    module Openshift
    end

    # TODO:  Make the manageiq-providers-kubernetes gem do this (all provider gems really)
    module Kubernetes
    end

    # TODO:  Do this somewhere else in the main repo
    module Inflector
    end
  end
end

# FIXME: Punting a bit here
class Metric < ApplicationRecord
end
require "metric/long_term_averages"
require "metric/ci_mixin"

require "manageiq/providers/inflector/methods" # needed for VmOrTemplate
# seems to be needed to make the aggregation_mixin function properly in
# app/models/ext_management_system, but that relationship might not be needed
# in general
require "vm_or_template"

require "ems_refresh/manager"
require "ems_refresh/refreshers/ems_refresher_mixin"
require "ext_management_system"

# TODO:  Make the manageiq-providers-kubernetes gem do this (all provider gems really)
$:.push(File.join(Gem::Specification.find_by_name('manageiq-providers-kubernetes').gem_dir, "app", "models"))

# TODO:  Make the manageiq-providers-openshift gem do this (all provider gems really)
$:.push(File.join(Gem::Specification.find_by_name('manageiq-providers-openshift').gem_dir, "app", "models"))

require "job"
require "miq_server"
require "zone"
require "miq_region"
require "server_role"
require "miq_queue"
require "settings_change"
require "authenticator"
require "session"

require "assigned_server_role"
require "miq_worker"
require "miq_worker/runner"
require "miq_queue_worker_base"
require "custom_attribute"
require "container"
require "container_condition"
require "container_group"
require "container_node"
require "manageiq/providers/base_manager"
require "manageiq/providers/base_manager/event_catcher"
require "manageiq/providers/base_manager/metrics_capture"
require "manageiq/providers/base_manager/metrics_collector_worker"
require "manageiq/providers/base_manager/refresh_worker"
require "manageiq/providers/container_manager"

module ManageIQ
  module Providers
    module Kubernetes
      # Has to be done here because we abuse autoloading too much
      class ContainerManager < ManageIQ::Providers::ContainerManager
      end
    end
  end
end

require "manageiq/providers/kubernetes/container_manager/event_catcher_mixin"
require "manageiq/providers/kubernetes/container_manager/event_parser_mixin"
require "manageiq/providers/kubernetes/container_manager/refresher_mixin"
require "manageiq/providers/kubernetes/container_manager/metrics_capture/hawkular_client_mixin"
require "manageiq/providers/kubernetes/container_manager/entities_mapping"
require "manageiq/providers/kubernetes/container_manager_mixin"
require "manageiq/providers/kubernetes/container_manager"
require "manageiq/providers/openshift/container_manager_mixin"
require "manageiq/providers/openshift/container_manager"
require "manageiq/providers/openshift/container_manager/metrics_collector_worker"
