require File.expand_path(File.dirname(__FILE__) + '/test_helper')

require 'digest/sha1'
require 'json'
require 'rack/test'

class Minitest::Spec
  include Rack::Test::Methods
  def app
    Resque::Server.new
  end
end

def setup_some_failed_jobs
  Resque.redis.flushall

  @worker = Resque::Worker.new(:jobs,:jobs2)

  create_and_process_jobs :jobs, @worker, 1, Time.now, BadJobWithSyntaxError, "great_args"

  10.times {|i|
    create_and_process_jobs :jobs, @worker, 1, Time.now, BadJob, "test_#{i}"
  }

  @cleaner = Resque::Plugins::ResqueCleaner.new
  @cleaner.print_message = false
end

describe "resque-web" do
  before do
    setup_some_failed_jobs
  end

  it "#cleaner should respond with success" do
    get "/cleaner"
    assert last_response.body.include?('BadJob')
    assert last_response.body =~ /\bException\b/
  end

  it "#cleaner_list should respond with success" do
    get "/cleaner_list"
    assert last_response.ok?, last_response.errors
  end

  it '#cleaner_list shows the failed jobs' do
    get "/cleaner_list"
    assert last_response.body.include?('BadJob')
  end

  it "#cleaner_list shows the failed jobs when we use a select_by_regex" do
    get "/cleaner_list", :regex => "BadJob*"
    assert last_response.body.include?('"BadJobWithSyntaxError"')
    assert last_response.body.include?('"BadJob"')
  end

  it '#cleaner_one shows the failed jobs' do
    get "/cleaner_one"
    assert_includes last_response.body, 'BadJob'
  end

  it '#cleaner_one shows the failed jobs for a class' do
    get "/cleaner_one", :c => "BadJobWithSyntaxError"
    assert_includes last_response.body, 'BadJobWithSyntaxError'
  end

  it '#cleaner_one shows only the first failed job for index 0' do
    get "/cleaner_one", :fsi => "0", :cf => "1"
    assert_includes last_response.body, 'BadJobWithSyntaxError'
  end

  it '#cleaner_one shows only the first failed job for index 1' do
    get "/cleaner_one", :fsi => "1", :cf => "1"
    assert_includes last_response.body, 'BadJob'
    assert_equal false, last_response.body.include?('BadJobWithSyntaxError')
  end

  it '#cleaner_exec clears job' do
    post "/cleaner_exec", :action => "clear", :sha1 => Digest::SHA1.hexdigest(@cleaner.select[0].inspect)
    assert_equal 10, @cleaner.select.size
  end

  it "#cleaner_dump should respond with success" do
    get "/cleaner_dump"
    assert last_response.ok?, last_response.errors
  end
end

