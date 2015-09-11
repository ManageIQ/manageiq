
cd rhus-chargeback
git pull gitlab
bundle install --without qpid
cp config/database.pg.yml config/database.yml
bin/rake db:migrate
bin/rake evm:restart
rspec spec/models
