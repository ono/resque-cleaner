#
# Setup
#

# load 'tasks/redis.rake'
#require 'rake/testtask'

$LOAD_PATH.unshift 'lib'
#require 'resque/tasks'

def command?(command)
  system("type #{command} > /dev/null 2>&1")
end


#
# Tests
#

task :default => :test

desc "Run the test suite"
task :test do
  Dir['test/**/*_test.rb'].each do |f|
    ruby(f)
  end
end

if command? :kicker
  desc "Launch Kicker (like autotest)"
  task :kicker do
    puts "Kicking... (ctrl+c to cancel)"
    exec "kicker -e rake test lib examples"
  end
end
