# client-side dependencies

# TODO replace with rails-assets-*
gem "jquery-rjs", "=0.1.1", :git => 'https://github.com/amatsuda/jquery-rjs.git'
  # TODO helpers?
gem 'jquery-rails', "~>4.0.4"
gem 'jquery-hotkeys-rails'
gem 'codemirror-rails', "=4.2"

# TODO probably need to keep this one?
gem 'patternfly-sass', "~>1.3.1"

source 'https://rails-assets.org' do
  gem 'rails-assets-c3', '~> 0.4.10'
  gem 'rails-assets-bootstrap-select', '~> 1.5.4'
  gem 'rails-assets-bootstrap-hover-dropdown', '~> 2.0.11'

  gem 'rails-assets-angular', '~>1.4.3'
  gem 'rails-assets-angular-mocks', '~> 1.4.3'

  gem 'rails-assets-angular-bootstrap', '~> 0.13.0'

  gem 'rails-assets-lodash', '~> 3.10.0'
  gem 'rails-assets-moment', '~> 2.10.3'
  gem 'rails-assets-bootstrap-datepicker', '~> 1.4.0'
end

# TODO matthewd's empty.rails-assets?
