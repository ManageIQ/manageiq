
source ~/.bash_profile
gem install bundler -v ">=1.8.4"
#bundle install --without qpid
bundle install --without qpid
cp config/database.pg.yml config/database.yml
cp certs/v2_key.dev certs/v2_key
bin/rake db:migrate RAILS_ENV=test
bin/rake evm:restart
rspec spec/controllers/chargeback_controller_spec.rb spec/helpers/application_helper_spec.rb spec/presenters/tree_builder_spec.rb spec/presenters/tree_node_builder_spec.rb spec/routing/chargeback_routing_spec.rb spec/models/chargeback_* spec/support/api_spec_helper.rb spec/requests/api/chargebacks_spec.rb spec/requests/api/collections_spec.rb spec/controllers/miq_report_controller/reports/editor_spec.rb spec/controllers/report_controller_spec.rb
git checkout master
