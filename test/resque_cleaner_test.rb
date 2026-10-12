require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require 'time'
describe "ResqueCleaner" do
  before do
    Resque.redis.redis.flushall

    @worker = Resque::Worker.new(:jobs,:jobs2)

    # 3 BadJob at 2009-03-13
    create_and_process_jobs :jobs, @worker, 3, Time.parse('2009-03-13'), BadJob
    # 2 BadJob by Jason at 2009-03-13
    create_and_process_jobs :jobs2, @worker, 2, Time.parse('2009-03-13'), BadJob, "Jason"

    # 1 BadJob by Johnson at 2009-03-13
    create_and_process_jobs :jobs, @worker, 1, Time.parse('2009-03-13'), BadJob, "Johnson"

    # 7 BadJob at 2009-11-13
    create_and_process_jobs :jobs, @worker, 7, Time.parse('2009-11-13'), BadJobWithSyntaxError
    # 7 BadJob by Freddy at 2009-11-13
    create_and_process_jobs :jobs2, @worker, 7, Time.parse('2009-11-13'), BadJob, "Freddy"

    # 11 BadJob at 2010-08-13
    create_and_process_jobs :jobs, @worker, 11, Time.parse('2010-08-13'), BadJob
    # 11 BadJob by Jason at 2010-08-13
    create_and_process_jobs :jobs2, @worker, 11, Time.parse('2010-08-13'), BadJob, "Jason"

    @cleaner = Resque::Plugins::ResqueCleaner.new
    @cleaner.print_message = false
  end

  it "#select_by_regex returns only Jason jobs" do
    ret = @cleaner.select_by_regex(/Jason/)
    assert_equal 13, ret.size
  end

  it "#select_by_regex returns an empty array if passed a non-regex" do
    ['string', nil, 13, Class.new].each do |non_regex|
      ret = @cleaner.select_by_regex(nil)
      assert_equal 0, ret.size
    end
  end

  it "#select returns failure jobs" do
    ret = @cleaner.select
    assert_equal 42, ret.size
  end

  it "#select works with a limit" do
    @cleaner.limiter.maximum = 10
    ret = @cleaner.select

    # only maximum number
    assert_equal 10, ret.size

    # lait one
    assert_equal Time.parse(ret[0]['failed_at']), Time.parse('2010-08-13')
  end

  it "#select with a block returns failure jobs which the block evaluates true" do
    ret = @cleaner.select {|job| job["payload"]["args"][0]=="Jason"}
    assert_equal 13, ret.size
  end

  it "#clear deletes failure jobs" do
    cleared = @cleaner.clear
    assert_equal 42, cleared
    assert_equal 0, @cleaner.select.size
  end

  it "#clear with a block deletes failure jobs which the block evaluates true" do
    cleared = @cleaner.clear{|job| job["payload"]["args"][0]=="Jason"}
    assert_equal 13, cleared
    assert_equal 42-13, @cleaner.select.size
    assert_equal 0, @cleaner.select{|job| job["payload"]["args"][0]=="Jason"}.size
  end

  it "#requeue retries failure jobs" do
    assert_equal 0, queue_size(:jobs,:jobs2)
    requeued = @cleaner.requeue
    assert_equal 42, requeued
    assert_equal 42, @cleaner.select.size # it doesn't clear jobs
    assert_equal 42, queue_size(:jobs,:jobs2)
  end

  it "#requeue preserves stored ActiveJob payloads and enqueues the wrapper" do
    Resque.redis.redis.flushall
    original = activejob_failure_data
    add_activejob_failure

    assert_equal 1, @cleaner.requeue(false)

    stored = Resque.decode(Resque.redis.lindex(:failed, 0))
    retried_at = stored.delete("retried_at")
    assert_match(/\A\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}\z/, retried_at)
    assert_equal Resque.decode(Resque.encode(original)), stored

    queued = Resque.peek(:queue, 0)
    assert_equal "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", queued["class"]
    assert_equal Resque.decode(Resque.encode(original[:payload][:args])), queued["args"]
  end

  it "#requeue retries the same ActiveJob failure repeatedly without corruption" do
    Resque.redis.redis.flushall
    add_activejob_failure

    2.times { assert_equal 1, @cleaner.requeue(false) }

    first = Resque.peek(:queue, 0)
    second = Resque.peek(:queue, 1)
    assert_equal first, second
    assert_equal "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", second["class"]
    assert_equal "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
      Resque.decode(Resque.redis.lindex(:failed, 0)).dig("payload", "class")
  end

  it "#requeue leaves a plain Resque payload unchanged" do
    Resque.redis.redis.flushall
    create_and_process_jobs :jobs, @worker, 1, Time.now, BadJob, "plain"
    original = Resque.decode(Resque.redis.lindex(:failed, 0))

    assert_equal 1, @cleaner.requeue(false)

    stored = Resque.decode(Resque.redis.lindex(:failed, 0))
    assert_equal original["payload"], stored["payload"]
  end

  it "#clear removes ActiveJob failures" do
    Resque.redis.redis.flushall
    add_activejob_failure

    assert_equal 1, @cleaner.clear
    assert_equal 0, @cleaner.failure.count
  end

  it "display helpers tolerate malformed ActiveJob wrapper arguments" do
    wrapper = "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
    malformed_args = [
      [nil, nil],
      ["invalid", "invalid"],
      [[123], [123]],
      [[{}], [{}]],
      [[{"arguments" => ["raw"]}], ["raw"]]
    ]

    malformed_args.each do |args, expected_display_args|
      job = {"payload" => {"class" => wrapper, "args" => args}}
      job.extend Resque::Plugins::ResqueCleaner::FailedJobEx

      assert_equal wrapper, job.display_class
      if expected_display_args.nil?
        assert_nil job.display_args
      else
        assert_equal expected_display_args, job.display_args
      end
      assert job.klass?(wrapper)
    end
  end

  it "display helpers reject malformed ActiveJob class names" do
    wrapper = "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"

    [[], {}, 123, false, nil, ""].each do |job_class|
      job = {
        "payload" => {
          "class" => wrapper,
          "args" => [{"job_class" => job_class, "arguments" => []}]
        }
      }
      job.extend Resque::Plugins::ResqueCleaner::FailedJobEx

      assert_equal wrapper, job.display_class
      assert job.klass?(wrapper)
    end
  end

  it "#requeue with a block retries failure jobs which the block evaluates true" do
    requeued = @cleaner.requeue{|job| job["payload"]["args"][0]=="Jason"}
    assert_equal 13, requeued
    assert_equal 13, queue_size(:jobs,:jobs2)
  end

  it "#requeue with clear option requeues and deletes failure jobs" do
    assert_equal 0, queue_size(:jobs,:jobs2)
    requeued = @cleaner.requeue(true)
    assert_equal 42, requeued
    assert_equal 42, queue_size(:jobs,:jobs2)
    assert_equal 0, @cleaner.select.size
  end

  it "#requeue with :queue option requeues the jobs to the queue" do
    assert_equal 0, queue_size(:jobs,:jobs2,:retry)
    requeued = @cleaner.requeue false, :queue => :retry
    assert_equal 42, requeued
    assert_equal 42, @cleaner.select.size # it doesn't clear jobs
    assert_equal 0, queue_size(:jobs,:jobs2)
    assert_equal 42, queue_size(:retry)
  end

  it "#clear_stale deletes failure jobs which is queued before the last x enqueued" do
    @cleaner.limiter.maximum = 10
    @cleaner.clear_stale
    assert_equal 10, @cleaner.failure.count
    assert_equal Time.parse(@cleaner.failure_jobs[0]['failed_at']), Time.parse('2010-08-13')
  end

  it "FailedJobEx module extends job and provides some useful methods" do
    # before 2009-04-01
    ret = @cleaner.select {|j| j.before?('2009-04-01')}
    assert_equal 6, ret.size

    # after 2010-01-01
    ret = @cleaner.select {|j| j.after?('2010-01-01')}
    assert_equal 22, ret.size

    # filter by class
    ret = @cleaner.select {|j| j.klass?(BadJobWithSyntaxError)}
    assert_equal 7, ret.size

    # filter by exception
    ret = @cleaner.select {|j| j.exception?(SyntaxError)}
    assert_equal 7, ret.size

    # filter by queue
    ret = @cleaner.select {|j| j.queue?(:jobs2)}
    assert_equal 20, ret.size

    # combination
    ret = @cleaner.select {|j| j.queue?(:jobs2) && j.before?('2009-12-01')}
    assert_equal 9, ret.size

    # combination 2
    ret = @cleaner.select {|j| j['payload']['args']==['Jason'] && j.queue?(:jobs2)}
    assert_equal 13, ret.size

    # retried?
    requeued = @cleaner.requeue{|j| j["payload"]["args"][0]=="Johnson"}
    ret = @cleaner.select {|j| j.retried?}
    assert_equal 1, ret.size
  end

  it "#stats_by_date returns stats grouped by date" do
    ret = @cleaner.stats_by_date
    assert_equal 6, ret['2009/03/13']
    assert_equal 14, ret['2009/11/13']

    # with block
    ret = @cleaner.stats_by_date{|j| j['payload']['args']==['Jason']}
    assert_equal 2, ret['2009/03/13']
    assert_nil ret['2009/11/13']
    assert_equal 11, ret['2010/08/13']
  end

  it "#stats_by_class returns stats grouped by class" do
    ret = @cleaner.stats_by_class
    assert_equal 35, ret['BadJob']
    assert_equal 7, ret['BadJobWithSyntaxError']
  end

  it "#stats_by_class works with broken log" do
    add_empty_payload_failure
    ret = @cleaner.stats_by_class
    assert_equal 1, ret['UNKNOWN']
  end

  it "#stats_by_exception returns stats grouped by exception" do
    ret = @cleaner.stats_by_exception
    assert_equal 35, ret['RuntimeError']
    assert_equal 7, ret['SyntaxError']
  end

  it "#lock ensures that a new failure job doesn't affect in a limit mode" do
    @cleaner.limiter.maximum = 23
    @cleaner.limiter.lock do
      first = @cleaner.select[0]
      assert_equal "Freddy", first["payload"]["args"][0]

      create_and_process_jobs :jobs, @worker, 30, Time.parse('2010-10-10'), BadJob, "Jack"

      first = @cleaner.select[0]
      assert_equal "Freddy", first["payload"]["args"][0]
    end
    first = @cleaner.select[0]
    assert_equal "Jack", first["payload"]["args"][0]
  end

  it "allows you to configure limiter" do
    c = Resque::Plugins::ResqueCleaner.new
    refute_equal c.limiter.maximum, 10_000

    module Resque::Plugins
      ResqueCleaner::Limiter.default_maximum = 10_000
    end

    c = Resque::Plugins::ResqueCleaner.new
    assert_equal c.limiter.maximum, 10_000
  end
end
