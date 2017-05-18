#!/usr/bin/env sh

# load envs
# clean old vcrs
# run tests
# obfuscate


# Migrate test db
RAILS_ENV=test bundle exec rake db:migrate

# Delete old VCRs, runnign test will create new
# these are VCRs for OpenStack Cloud Provider Refresh
rm spec/vcr_cassettes/manageiq/providers/openstack/cloud_manager/*.*

# these are VCRs for OpenStack Infra Provider Refresh
# rm spec/vcr_cassettes/manageiq/providers/openstack/infra_manager/refresher_rhos_juno.yml

# Load the credentials into test
bundle exec rails r spec/tools/environment_builders/openstack_environments.rb --load

# Run the tests
# these are specs for OpenStack Cloud Provider Refresh
bundle exec rspec spec/models/manageiq/providers/openstack/cloud_manager/refresher_rhos_*

# these are specs for OpenStack Infra Provider Refresh
# bundle exec rspec spec/models/manageiq/providers/openstack/infra_manager/refresher_rhos_juno_spec.rb

# Obfuscate the VCRs and test so it doesn't contain real IPs and passwords
bundle exec rails r spec/tools/environment_builders/openstack_environments.rb --obfuscate
