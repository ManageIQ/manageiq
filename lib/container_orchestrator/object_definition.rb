class ContainerOrchestrator
  module ObjectDefinition
    private

    def deployment_definition(name)
      {
        :metadata => {
          :name            => name,
          :labels          => {:app => app_name},
          :namespace       => my_namespace,
          :ownerReferences => owner_references
        },
        :spec     => {
          :selector => {:matchLabels => {:name => name}},
          :template => {
            :metadata => {:name => name, :labels => {:name => name, :app => app_name}},
            :spec     => {
              :imagePullSecrets   => [{:name => ENV["IMAGE_PULL_SECRET"].to_s}],
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
          :labels          => {:app => app_name},
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
          :labels          => {:app => app_name},
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
        {:name => "MESSAGING_PORT",          :value => ENV["MESSAGING_PORT"]},
        {:name => "MESSAGING_TYPE",          :value => ENV["MESSAGING_TYPE"]},
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
         :valueFrom => {:secretKeyRef=>{:name => "app-secrets", :key => "encryption-key"}}},
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
        :initialDelaySeconds => 120,
        :timeoutSeconds      => 1
      }
    end

    NAMESPACE_FILE = "/run/secrets/kubernetes.io/serviceaccount/namespace".freeze
    def my_namespace
      @my_namespace ||= File.read(NAMESPACE_FILE)
    end

    def app_name
      ENV["APP_NAME"]
    end

    def owner_references
      [{
        :apiVersion         => "v1",
        :blockOwnerDeletion => true,
        :controller         => true,
        :kind               => "Pod",
        :name               => ENV["POD_NAME"],
        :uid                => ENV["POD_UID"]
      }]
    end
  end
end
