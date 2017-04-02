module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin
      include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin

      KUBERNETES_EMS_TYPE = ManageIQ::Providers::Kubernetes::ContainerManager.ems_type

      OPENSHIFT_ENTITIES = [
        {:name => 'routes'}, {:name => 'projects'},
        {:name => 'build_configs'}, {:name => 'builds'}, {:name => 'templates'},
        {:name => 'images'}
      ]

      def fetch_hawk_inv(ems)
        hawk = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(ems, '_ops')
        keys = hawk.strings.query(:miq_metric => true)
        keys.each_with_object({}) do |k, attributes|
          values = hawk.strings.get_data(k.json["id"], :limit => 1, :order => "DESC")
          attributes[k.json["id"]] = values.first["value"] unless values.empty?
        end
      rescue => err
        _log.error err.message
        return nil
      end

      def parse_legacy_inventory(ems)
        kube_entities = ems.with_provider_connection(:service => KUBERNETES_EMS_TYPE) do |kubeclient|
          fetch_entities(kubeclient, KUBERNETES_ENTITIES)
        end
        openshift_entities = ems.with_provider_connection do |openshift_client|
          fetch_entities(openshift_client, OPENSHIFT_ENTITIES)
        end
        entities = openshift_entities.merge(kube_entities)
        _inflate(entities)
        entities["additional_attributes"] = fetch_hawk_inv(ems) || {}
        EmsRefresh.log_inv_debug_trace(entities, "inv_hash:")

        res = nil
        puts "parser:", Benchmark.measure {  res = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_hashes(entities) }
        res
      end

      # DEBUGGING
      INFLATE_FACTOR = ENV['CONTAINER_INFLATE_FACTOR'] ? ENV['CONTAINER_INFLATE_FACTOR'].to_i : 1

      def _inflate(inventory)
        return if INFLATE_FACTOR == 1
        inventory.each do |k, structs|
          orig = structs.dup
          orig.each do |s|
            (2..INFLATE_FACTOR).each do |i|
              copy = s.deep_dup
              # Hopefully most cross-refs are by name relative to current namespace?
              case k
              when "image", "node", "component_status"
                # not inflated. TODO?
                next
              when "project", "namespace"
                copy.metadata.name += "_inflate#{i}"
              else
                byebug unless copy.metadata.namespace
                copy.metadata.namespace += "_inflate#{i}"
              end
              byebug unless copy.metadata.uid
              copy.metadata.uid += "_inflate#{i}"
              # selfLink doesn't matter.

              structs << copy
            end
          end
          puts "CONTAINER_INFLATE_FACTOR=#{INFLATE_FACTOR}: #{k}: \t#{orig.size} -> #{structs.size}"
        end
      end
    end
  end
end
