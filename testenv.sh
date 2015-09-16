
source ~/.bash_profile
cd rhus-chargeback
gem install bundler -v ">=1.8.4"
#bundle install --without qpid
bundle install --without qpid
cp config/database.pg.yml config/database.yml
bin/rake db:migrate
bin/rake evm:restart
rspec spec/controllers/chargeback_controller_spec.rb spec/helpers/application_helper_spec.rb spec/presenters/tree_builder_spec.rb spec/presenters/tree_node_builder_spec.rb spec/routing/chargeback_routing_spec.rb spec/models/chargeback_* spec/support/api_spec_helper.rb spec/requests/api/chargebacks_spec.rb spec/requests/api/collections_spec.rb spec/controllers/miq_report_controller/reports/editor_spec.rb spec/controllers/report_controller_spec.rb
