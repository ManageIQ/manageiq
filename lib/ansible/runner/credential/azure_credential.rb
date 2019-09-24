module Ansible
  class Runner
    class AzureCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential"
      end

      # Modeled off of azure injectors for awx:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L45-L60
      #
      # NOTE:  We don't currently support the AZURE_CLOUD_ENVIRONMENT variable
      # as a configurable option.
      #
      def env_vars
        if auth.options && auth.options[:client].present? && auth.options[:tenant].present?
          {
            "AZURE_CLIENT_ID"       => (auth.options || {})[:client],
            "AZURE_TENANT"          => (auth.options || {})[:tenant],
            "AZURE_SECRET"          => auth.auth_key || "",
            "AZURE_SUBSCRIPTION_ID" => (auth.options || {})[:subscription] || ""
          }
        else
          {
            "AZURE_AD_USER"         => auth.userid || "",
            "AZURE_PASSWORD"        => auth.password || "",
            "AZURE_SUBSCRIPTION_ID" => (auth.options || {})[:subscription] || ""
          }
        end
      end
    end
  end
end
