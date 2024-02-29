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
              :affinity           => {
                :nodeAffinity => {
                  :requiredDuringSchedulingIgnoredDuringExecution => {
                    :nodeSelectorTerms => [{
                      :matchExpressions => [
                        {:key => "kubernetes.io/arch", :operator => "In", :values => ContainerOrchestrator.new.my_node_affinity_arch_values}
                      ]
}]
                  }
                }
              },
              :serviceAccountName => ENV.fetch("WORKER_SERVICE_ACCOUNT", nil),
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
              :volumes            => [
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
      else
        deployment[:spec][:template][:spec][:containers][0][:volumeMounts] ||= []
        deployment[:spec][:template][:spec][:containers][0][:volumeMounts] << {
          :mountPath => "/etc/pki/ca-trust/source/anchors",
          :name      => "messaging-certificate",
          :readOnly  => true,
        }

        deployment[:spec][:template][:spec][:volumes] ||= []
        deployment[:spec][:template][:spec][:volumes] << {
          :name   => "messaging-certificate",
          :secret => {
            :secretName => "manageiq-cluster-ca-cert",
            :items      => [
              :key  => "ca.crt",
              :path => "ca.crt",
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
        {:name => "APPLICATION_DOMAIN",      :value => ENV.fetch("APPLICATION_DOMAIN", nil)},
        {:name => "MEMCACHED_SERVER",        :value => ENV.fetch("MEMCACHED_SERVER", nil)},
        {:name => "MEMCACHED_SERVICE_NAME",  :value => ENV.fetch("MEMCACHED_SERVICE_NAME", nil)},
        {:name => "WORKER_HEARTBEAT_FILE",   :value => Rails.root.join("tmp/worker.hb").to_s},
        {:name => "WORKER_HEARTBEAT_METHOD", :value => "file"},
      ] + database_environment + memcached_environment + messaging_environment
    end

    def database_environment
      [
        {:name => "DATABASE_SSL_MODE", :value => ENV.fetch("DATABASE_SSL_MODE", nil)},
      ]
    end

    def memcached_environment
      return [] unless ENV["MEMCACHED_ENABLE_SSL"].present?

      [
        {:name => "MEMCACHED_ENABLE_SSL", :value => ENV.fetch("MEMCACHED_ENABLE_SSL", nil)},
        {:name => "MEMCACHED_SSL_CA",     :value => ENV.fetch("MEMCACHED_SSL_CA", nil)},
      ]
    end

    def messaging_environment
      return [] unless ENV["MESSAGING_TYPE"].present?

      [
        {:name => "MESSAGING_PORT", :value => ENV.fetch("MESSAGING_PORT", nil)},
        {:name => "MESSAGING_TYPE", :value => ENV.fetch("MESSAGING_TYPE", nil)},
        {:name => "MESSAGING_SSL_CA", :value => ENV.fetch("MESSAGING_SSL_CA", nil)},
        {:name => "MESSAGING_SASL_MECHANISM", :value => ENV.fetch("MESSAGING_SASL_MECHANISM", nil)},
        {:name => "MESSAGING_HOSTNAME", :value => ENV.fetch("MESSAGING_HOSTNAME", nil)},
        {:name => "MESSAGING_PASSWORD", :value => ENV.fetch("MESSAGING_PASSWORD", nil)},
        {:name => "MESSAGING_USERNAME", :value => ENV.fetch("MESSAGING_USERNAME", nil)}
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
      ENV.fetch("APP_NAME", nil)
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
      ENV.fetch('POD_NAME', nil)
    end

    def pod_uid
      ENV.fetch("POD_UID", nil)
    end
  end
end
