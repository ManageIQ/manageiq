class FixNullVerifySslOnEndpoints < ActiveRecord::Migration[5.0]
  # 20151222103721_migrate_provider_attributes_to_endpoints.rb
  # this migration moved verify_ssl from the Provider class to Endpoint
  # but a lot of ems at this point did not have a Provider
  # That resulted in verify_ssl being nil for all Endpoint,
  # but the Endpoint class requires it being not nil
  class Endpoint < ActiveRecord::Base
  end

  def up
    say_with_time("Fixing defaults for verify_ssl in Endpoint") do
      # at the point of writing this is the default for verify_ssl
      # OpenSSL::SSL::VERIFY_PEER == 1 in ruby stdlib 2.3.1
      Endpoint.where(:verify_ssl => nil).update_all(:verify_ssl => 1)
    end
  end

  def down
    # irreversible, sorry
  end
end
