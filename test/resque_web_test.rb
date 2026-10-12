require File.expand_path(File.dirname(__FILE__) + '/test_helper')

require 'digest/sha1'
require 'json'
require 'rack/test'

Resque::Server.set :host_authorization, permitted_hosts: []

class Minitest::Spec
  include Rack::Test::Methods
  def app
    Resque::Server.new
  end
end

def setup_some_failed_jobs
  Resque.redis.redis.flushall

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

  it '#cleaner_list filters and displays ActiveJob failures by the inner class' do
    add_activejob_failure

    get "/cleaner"
    assert last_response.ok?, last_response.errors
    assert_includes last_response.body, 'ActiveJobGoodJob'
    refute_includes last_response.body, 'ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper'

    get "/cleaner_list", :c => "ActiveJobGoodJob"

    assert last_response.ok?, last_response.errors
    assert_includes last_response.body, '<option selected="selected" value="ActiveJobGoodJob">ActiveJobGoodJob</option>'
    assert_includes last_response.body, '<code>ActiveJobGoodJob</code>'
    assert_includes last_response.body, 'good_job'
    refute_includes last_response.body, '<code>ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper</code>'

    get "/cleaner_dump", :c => "ActiveJobGoodJob"
    dumped = JSON.parse(last_response.body)
    assert_equal 1, dumped.size
    assert_equal "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", dumped[0].dig("payload", "class")
    assert_equal "ActiveJobGoodJob", dumped[0].dig("payload", "args", 0, "job_class")
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

  it "#cleaner_list rejects invalid and runaway regex filters" do
    get "/cleaner_list", :regex => "("
    assert_equal 400, last_response.status

    Resque.redis.rpush(:failed, Resque.encode(
      :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
      :payload   => { :class => "a" * 40 + "!", :args => [] },
      :exception => "RuntimeError",
      :worker    => "worker",
      :queue     => "jobs"
    ))
    get "/cleaner_list", :regex => '(a+)+\1![a-z]'
    assert_equal 400, last_response.status
  end

  it "#cleaner_list shows escaped XSS attempt" do
    get "/cleaner_list?t=%22%3e%3cscript%3ealert(document.cookie)%3c%2fscript%3e"
    assert last_response.body.include?('&quot;&gt;&lt;script&gt;alert(document.cookie)&lt;')
    refute last_response.body.include?('<script>alert(document.cookie)')
  end

  it "cleaner pages tolerate malformed ActiveJob wrapper arguments" do
    data = activejob_failure_data
    data[:payload][:args] = "invalid"
    Resque.redis.rpush(:failed, Resque.encode(data))

    get "/cleaner"
    assert last_response.ok?, last_response.errors
    assert_includes last_response.body, "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"

    get "/cleaner_list"
    assert last_response.ok?, last_response.errors
    assert_includes last_response.body, "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
  end

  it "cleaner pages tolerate malformed ActiveJob class names" do
    data = activejob_failure_data
    data[:payload][:args][0][:job_class] = []
    Resque.redis.rpush(:failed, Resque.encode(data))

    get "/cleaner"
    assert last_response.ok?, last_response.errors
    assert_includes last_response.body, "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"

    get "/cleaner_list"
    assert last_response.ok?, last_response.errors
    assert_includes last_response.body, "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
  end

  it "escapes persisted failure values" do
    Resque.redis.rpush(:failed, Resque.encode(
      :failed_at  => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
      :payload    => { :class => %q{"><script>alert(1)</script>}, :args => [] },
      :exception  => %q{"><script>alert(2)</script>},
      :error      => "error",
      :backtrace  => [],
      :worker     => %q{worker"><script>alert(3)</script>:123:queue},
      :queue      => %q{"><script>alert(4)</script>},
      :retried_at => %q{"><script>alert(5)</script>}
    ))

    get "/cleaner"
    (1..2).each do |number|
      assert_includes last_response.body, "&quot;&gt;&lt;script&gt;alert(#{number})&lt;"
      refute_includes last_response.body, "<script>alert(#{number})"
    end

    get "/cleaner_list"
    (1..5).each do |number|
      assert_includes last_response.body, "&quot;&gt;&lt;script&gt;alert(#{number})&lt;"
      refute_includes last_response.body, "<script>alert(#{number})"
    end
  end

  it '#cleaner_exec clears job' do
    post "/cleaner_exec", :action => "clear", :sha1 => Digest::SHA1.hexdigest(@cleaner.select[0].to_json)
    assert_equal 10, @cleaner.select.size
  end

  it "#cleaner_dump should respond with success" do
    get "/cleaner_dump"
    assert last_response.ok?, last_response.errors
  end
end

