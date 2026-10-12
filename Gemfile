source 'https://rubygems.org'

gemspec

gem 'resque', "~> #{ENV['RESQUE_VERSION']}.0" if ENV['RESQUE_VERSION']
gem 'rack', "~> #{ENV['RACK_VERSION']}.0" if ENV['RACK_VERSION']

group :test do
  gem 'rake'
  gem 'json'
  gem 'timecop'
  gem 'minitest'
  gem 'rack-test'
end
