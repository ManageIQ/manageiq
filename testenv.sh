
source ~/.bash_profile
cd rhus-chargeback
gem install bundler -v ">=1.8.4"
#bundle install --without qpid
bundle install --without qpid
cp config/database.pg.yml config/database.yml
bin/rake db:migrate
bin/rake evm:restart
rspec spec/models
