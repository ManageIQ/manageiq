# rubocop:disable Rails/RakeEnvironment
require_relative "test_security_helper"

namespace :test do
  namespace :security do
    task :setup # NOOP - Stub for consistent CI testing

    desc "Run Brakeman with the specified report format ('human' or 'json')"
    task :brakeman, :format do |_, args|
      format = args.fetch(:format, "human")
      TestSecurityHelper.brakeman(format: format)
    rescue TestSecurityHelper::SecurityTestFailed
      exit 1
    end

    desc "Run bundle-audit with the specified report format ('human' or 'json')"
    task :bundle_audit, :format do |_, args|
      format = args.fetch(:format, "human")
      TestSecurityHelper.bundle_audit(format: format)
    rescue TestSecurityHelper::SecurityTestFailed
      exit 1
    end

    desc "Run yarn npm audit with the specified report format ('human' or 'json')"
    task :yarn_audit, :format do |_, args|
      format = args.fetch(:format, "human")
      TestSecurityHelper.yarn_audit(format: format)
    rescue TestSecurityHelper::SecurityTestFailed
      exit 1
    end

    desc "Rebuild yarn audit pending list for an engine"
    task :rebuild_yarn_audit_pending do
      TestSecurityHelper.rebuild_yarn_audit_pending
    end
  end

  desc "Run all security tests with the specified report format ('human' or 'json')"
  task :security, :format do |_, args|
    format = args.fetch(:format, "human")
    TestSecurityHelper.all(format: format)
  rescue TestSecurityHelper::SecurityTestFailed
    exit 1
  end
end

# rubocop:enable Rails/RakeEnvironment
