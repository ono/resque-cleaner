# Mostly copied from Resque in order to have similar test environment.
# https://github.com/defunkt/resque/blob/master/test/test_helper.rb

dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true
require 'rubygems'
require 'minitest'
require 'minitest/spec'
require 'minitest/autorun'
require 'resque'
require 'timecop'

begin
  require 'leftright'
rescue LoadError
end
require 'resque'
require 'resque_cleaner'

$TEST_PID = Process.pid

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end


#
# start our own redis when the tests start,
# kill it when they end
#
MiniTest.after_run {
  if Process.pid == $TEST_PID
    processes = `ps -A -o pid,command | grep [r]edis-test`.split($/)
    pids = processes.map { |process| process.split(" ")[0] }
    puts "Killing test redis server..."
    pids.each { |pid| Process.kill("TERM", pid.to_i) }
    dump = "test/dump.rdb"
    File.delete(dump) if File.exist?(dump)
  end
}

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
Resque.redis = 'localhost:9736'


##
# Helper to perform job classes
#
module PerformJob
  def perform_job(klass, *args)
    resque_job = Resque::Job.new(:testqueue, 'class' => klass, 'args' => args)
    resque_job.perform
  end
end

#
# fixture classes
#

class SomeJob
  def self.perform(repo_id, path)
  end
end

class SomeIvarJob < SomeJob
  @queue = :ivar
end

class SomeMethodJob < SomeJob
  def self.queue
    :method
  end
end

class BadJob
  def self.perform(name=nil)
    msg = name ? "Bad job, #{name}" : "Bad job!"
    raise msg
  end
end

class GoodJob
  def self.perform(name)
    "Good job, #{name}"
  end
end

class BadJobWithSyntaxError
  def self.perform
    raise SyntaxError, "Extra Bad job!"
  end
end

#
# helper methods
#

def create_and_process_jobs(queue,worker,num,date,job,*args)
  Timecop.freeze(date) do
    num.times do
      Resque::Job.create(queue, job, *args)
    end
    worker.work(0)
  end
end

def queue_size(*queues)
  queues.inject(0){|sum,queue| sum + Resque.size(queue).to_i}
end

def add_empty_payload_failure
  data = {
    :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
    :payload   => nil,
    :exception => "Resque::DirtyExit",
    :error     => "Resque::DirtyExit",
    :backtrace => [],
    :worker    => "worker",
    :queue     => "queue"
  }
  data = Resque.encode(data)
  Resque.redis.rpush(:failed, data)
end

def add_activejob_failure
  data = {
    :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
    :payload   => {
      :class => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
      :args  => [
        :job_class => "ActiveJobGoodJob",
        :job_id    => "0bc036ab-32c0-4ad0-9138-abdfb06658c4",
        :provider_job_id => nil,
        :queue_name => "download_scrape_job",
        :priority => nil,
        :arguments => [:good_job],
        :executions => 0,
        :exception_executions => {},
        :locale => "en",
        :timezone => "UTC",
        :enqueued_at => "2020-10-13T16:37:18Z"
      ]
    },
    :exception => "Resque::DirtyExit",
    :error     => "Resque::DirtyExit",
    :backtrace => [],
    :worker    => "worker",
    :queue     => "queue"
  }
  data = Resque.encode(data)
  Resque.redis.rpush(:failed, data)
end
