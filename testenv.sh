
cd rhus-chargeback
ls
#bundle install --without qpid
~/.rvm/gems/ruby-2.0.0-p643/bin/bundle install --without qpid
cp config/database.pg.yml config/database.yml
bin/rake db:migrate
bin/rake evm:restart
rspec spec/models
