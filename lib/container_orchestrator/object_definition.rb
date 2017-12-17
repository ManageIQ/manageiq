class ContainerOrchestrator
  module ObjectDefinition
    private

    def deployment_config_definition(name)
      {
        :metadata => {
          :name      => name,
          :labels    => {:app => app_name},
          :namespace => my_namespace,
        },
        :spec     => {
          :selector => {:name => name, :app => app_name},
          :template => {
            :metadata => {:name => name, :labels => {:name => name, :app => app_name}},
            :spec     => {
              :serviceAccount     => "miq-anyuid",
              :serviceAccountName => "miq-anyuid",
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

    def service_definition(name, port)
      {
        :metadata => {
          :name      => name,
          :labels    => {:app => app_name},
          :namespace => my_namespace
        },
        :spec     => {
          :selector => {:name => name},
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
          :name      => name,
          :labels    => {:app => app_name},
          :namespace => my_namespace
        },
        :stringData => string_data
      }
    end

    def default_environment
      [
        {:name => "DATABASE_SERVICE_NAME",   :value => ENV["DATABASE_SERVICE_NAME"]},
        {:name => "GUID",                    :value => MiqServer.my_guid},
        {:name => "MEMCACHED_SERVER",        :value => ENV["MEMCACHED_SERVER"]},
        {:name => "MEMCACHED_SERVICE_NAME",  :value => ENV["MEMCACHED_SERVICE_NAME"]},
        {:name => "WORKER_HEARTBEAT_FILE",   :value => Rails.root.join("tmp", "worker.hb").to_s},
        {:name => "WORKER_HEARTBEAT_METHOD", :value => "file"},
        {:name      => "DATABASE_URL",
         :valueFrom => {:secretKeyRef=>{:name => "#{app_name}-secrets", :key => "database-url"}}},
        {:name      => "V2_KEY",
         :valueFrom => {:secretKeyRef=>{:name => "#{app_name}-secrets", :key => "v2-key"}}}
      ]
    end

    def liveness_probe
      {
        :exec                => {:command => ["/usr/local/bin/manageiq_liveness_check"]},
        :initialDelaySeconds => 120,
        :timeoutSeconds      => 1
      }
    end

    def my_namespace
      ENV["MY_POD_NAMESPACE"]
    end

    def app_name
      Vmdb::Appliance.PRODUCT_NAME.downcase
    end
  end
end
