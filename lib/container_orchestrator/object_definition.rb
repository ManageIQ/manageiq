class ContainerOrchestrator
  module ObjectDefinition
    private

    def deployment_definition(name)
      deployment = {
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
                :name            => name,
                :env             => default_environment,
                :livenessProbe   => liveness_probe,
                :securityContext => {
                  :allowPrivilegeEscalation => false,
                  :privileged               => false,
                  :runAsNonRoot             => true,
                  :capabilities             => {
                    :drop => ["ALL"]
                  }
                },
                :volumeMounts    => [
                  {:name => "database-secret", :readOnly => true, :mountPath => "/run/secrets/postgresql"},
                  {:name => "encryption-key", :readOnly => true, :mountPath => "/run/secrets/manageiq/application"},
                ]
              }],
              :volumes => [
                {
                  :name   => "database-secret",
                  :secret => {
                    :secretName => "postgresql-secrets",
                    :items      => [
                      {:key => "dbname",   :path => "POSTGRESQL_DATABASE"},
                      {:key => "hostname", :path => "POSTGRESQL_HOSTNAME"},
                      {:key => "password", :path => "POSTGRESQL_PASSWORD"},
                      {:key => "port",     :path => "POSTGRESQL_PORT"},
                      {:key => "username", :path => "POSTGRESQL_USER"},
                    ],
                  }
                },
                {
                  :name   => "encryption-key",
                  :secret => {
                    :secretName => "app-secrets",
                    :items      => [
                      {:key => "encryption-key", :path => "encryption_key"},
                    ],
                  }
                }
              ]
            },
          }
        }
      }

      if File.file?("/.postgresql/root.crt")
        deployment[:spec][:template][:spec][:containers][0][:volumeMounts] << {
          :mountPath => "/.postgresql",
          :name      => "pg-root-certificate",
          :readOnly  => true,
        }

        deployment[:spec][:template][:spec][:volumes] << {
          :name   => "pg-root-certificate",
          :secret => {
            :secretName => "postgresql-secrets",
            :items      => [
              :key  => "rootcertificate",
              :path => "root.crt",
            ],
          }
        }
      end

      if ENV["SSL_SECRET_NAME"].present?
        deployment[:spec][:template][:spec][:containers][0][:volumeMounts] ||= []
        deployment[:spec][:template][:spec][:containers][0][:volumeMounts] << {
          :mountPath => "/etc/pki/ca-trust/source/anchors",
          :name      => "internal-root-certificate",
          :readOnly  => true,
        }

        deployment[:spec][:template][:spec][:volumes] ||= []
        deployment[:spec][:template][:spec][:volumes] << {
          :name   => "internal-root-certificate",
          :secret => {
            :secretName => ENV["SSL_SECRET_NAME"],
            :items      => [
              :key  => "root_crt",
              :path => "root.crt",
            ],
          }
        }
      end

      deployment
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
        {:name => "GUID",                    :value => MiqServer.my_guid},
        {:name => "HOME",                    :value => Rails.root.join("tmp").to_s},
        {:name => "MEMCACHED_SERVER",        :value => ENV["MEMCACHED_SERVER"]},
        {:name => "MEMCACHED_SERVICE_NAME",  :value => ENV["MEMCACHED_SERVICE_NAME"]},
        {:name => "WORKER_HEARTBEAT_FILE",   :value => Rails.root.join("tmp", "worker.hb").to_s},
        {:name => "WORKER_HEARTBEAT_METHOD", :value => "file"},
      ] + database_environment + memcached_environment + messaging_environment
    end

    def database_environment
      [
        {:name => "DATABASE_SSL_MODE", :value => ENV["DATABASE_SSL_MODE"]},
      ]
    end

    def memcached_environment
      return [] unless ENV["MEMCACHED_ENABLE_SSL"].present?

      [
        {:name => "MEMCACHED_ENABLE_SSL", :value => ENV["MEMCACHED_ENABLE_SSL"]},
        {:name => "MEMCACHED_SSL_CA",     :value => ENV["MEMCACHED_SSL_CA"]},
      ]
    end

    def messaging_environment
      return [] unless ENV["MESSAGING_TYPE"].present?

      [
        {:name => "MESSAGING_PORT", :value => ENV["MESSAGING_PORT"]},
        {:name => "MESSAGING_TYPE", :value => ENV["MESSAGING_TYPE"]},
        {:name => "MESSAGING_SSL_CA", :value => ENV["MESSAGING_SSL_CA"]},
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
