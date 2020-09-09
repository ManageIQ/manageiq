class ContainerOrchestrator
  module ObjectDefinition
    private

    def deployment_definition(name)
      {
        :metadata => {
          :name            => name,
          :labels          => common_labels,
          :namespace       => my_namespace,
          :ownerReferences => owner_references
        },
        :spec     => {
          :selector => {:matchLabels => {:name => name}},
          :template => {
            :metadata => {:name => name, :labels => common_labels.merge(:name => name)},
            :spec     => {
              :serviceAccountName => ENV["WORKER_SERVICE_ACCOUNT"],
              :containers         => [{
                :name          => name,
                :env           => default_environment,
                :livenessProbe => liveness_probe
              }]
            }
          }
        }
      }
    end

    def service_definition(name, selector, port)
      {
        :metadata => {
          :name            => name,
          :labels          => common_labels,
          :namespace       => my_namespace,
          :ownerReferences => owner_references
        },
        :spec     => {
          :selector => selector,
          :ports    => [{
            :name       => "#{name}-#{port}",
            :port       => port,
            :targetPort => port
          }]
        }
      }
    end

    def secret_definition(name, string_data)
      {
        :metadata   => {
          :name            => name,
          :labels          => common_labels,
          :namespace       => my_namespace,
          :ownerReferences => owner_references
        },
        :stringData => string_data
      }
    end

    def default_environment
      [
        {:name => "DATABASE_PORT",           :value => ENV["DATABASE_PORT"]},
        {:name => "GUID",                    :value => MiqServer.my_guid},
        {:name => "MEMCACHED_SERVER",        :value => ENV["MEMCACHED_SERVER"]},
        {:name => "MEMCACHED_SERVICE_NAME",  :value => ENV["MEMCACHED_SERVICE_NAME"]},
        {:name => "WORKER_HEARTBEAT_FILE",   :value => Rails.root.join("tmp", "worker.hb").to_s},
        {:name => "WORKER_HEARTBEAT_METHOD", :value => "file"},
        {:name      => "DATABASE_HOSTNAME",
         :valueFrom => {:secretKeyRef=>{:name => "postgresql-secrets", :key => "hostname"}}},
        {:name      => "DATABASE_NAME",
         :valueFrom => {:secretKeyRef=>{:name => "postgresql-secrets", :key => "dbname"}}},
        {:name      => "DATABASE_PASSWORD",
         :valueFrom => {:secretKeyRef=>{:name => "postgresql-secrets", :key => "password"}}},
        {:name      => "DATABASE_USER",
         :valueFrom => {:secretKeyRef=>{:name => "postgresql-secrets", :key => "username"}}},
        {:name      => "ENCRYPTION_KEY",
         :valueFrom => {:secretKeyRef=>{:name => "app-secrets", :key => "encryption-key"}}}
      ] + messaging_environment
    end

    def messaging_environment
      return [] unless ENV["MESSAGING_TYPE"].present?

      [
        {:name => "MESSAGING_PORT", :value => ENV["MESSAGING_PORT"]},
        {:name => "MESSAGING_TYPE", :value => ENV["MESSAGING_TYPE"]},
        {:name      => "MESSAGING_HOSTNAME",
         :valueFrom => {:secretKeyRef=>{:name => "kafka-secrets", :key => "hostname"}}},
        {:name      => "MESSAGING_PASSWORD",
         :valueFrom => {:secretKeyRef=>{:name => "kafka-secrets", :key => "password"}}},
        {:name      => "MESSAGING_USERNAME",
         :valueFrom => {:secretKeyRef=>{:name => "kafka-secrets", :key => "username"}}}
      ]
    end

    def liveness_probe
      {
        :exec                => {:command => ["/usr/local/bin/manageiq_liveness_check"]},
        :initialDelaySeconds => 240,
        :timeoutSeconds      => 10,
        :periodSeconds       => 15
      }
    end

    NAMESPACE_FILE = "/run/secrets/kubernetes.io/serviceaccount/namespace".freeze
    def my_namespace
      @my_namespace ||= File.read(NAMESPACE_FILE)
    end

    def app_name
      ENV["APP_NAME"]
    end

    def app_name_label
      {:app => app_name}
    end

    def app_name_selector
      "app=#{app_name}"
    end

    def common_labels
      app_name_label.merge(orchestrated_by_label)
    end

    def orchestrated_by_label
      {:"#{app_name}-orchestrated-by" => pod_name}
    end

    def orchestrated_by_selector
      "#{app_name}-orchestrated-by=#{pod_name}"
    end

    def owner_references
      [{
        :apiVersion         => "v1",
        :blockOwnerDeletion => true,
        :controller         => true,
        :kind               => "Pod",
        :name               => pod_name,
        :uid                => pod_uid
      }]
    end

    def pod_name
      ENV['POD_NAME']
    end

    def pod_uid
      ENV["POD_UID"]
    end
  end
end
