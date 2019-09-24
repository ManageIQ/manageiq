module Ansible
  class Runner
    class GenericCredential < Credential
      def self.auth_type
        ""
      end
    end
  end
end
