require File.expand_path(File.dirname(__FILE__) + '/test_helper')

# Pull in the server test_helper from resque
require 'resque/server/test_helper.rb'
require 'digest/sha1'
require 'json'

def setup_some_failed_jobs
  Resque.redis.flushall

  @worker = Resque::Worker.new(:jobs,:jobs2)

  10.times {|i|
    create_and_process_jobs :jobs, @worker, 1, Time.now, BadJob, "test_#{i}"
  }

  @cleaner = Resque::Plugins::ResqueCleaner.new
  @cleaner.print_message = false
end

context "resque-web" do
  setup do
    setup_some_failed_jobs
  end

  test "#cleaner should respond with success" do
    get "/cleaner_list"
    assert last_response.ok?, last_response.errors
  end

  test "#cleaner_list should respond with success" do
    get "/cleaner_list"
    assert last_response.ok?, last_response.errors
  end

  test '#cleaner_list shows the failed jobs' do
    get "/cleaner_list"
    assert last_response.body.include?('BadJob')
  end

  test '#cleaner_exec clears job' do
    post "/cleaner_exec", :action => "clear", :sha1 => Digest::SHA1.hexdigest(@cleaner.select[0].to_json)
    assert_equal 9, @cleaner.select.size
  end
  test "#cleaner_dump should respond with success" do
    get "/cleaner_dump"
    assert last_response.ok?, last_response.errors
  end
end

