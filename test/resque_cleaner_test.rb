require File.dirname(__FILE__) + '/test_helper'
require 'time'
context "ResqueCleaner" do
  def create_and_process_jobs(worker,num,date,job,*args)
    Timecop.freeze(date) do
      num.times do
        Resque::Job.create(:jobs, job, *args)
      end
      worker.work(0)
    end
  end

  setup do
    Resque.redis.flushall

    @worker = Resque::Worker.new(:jobs)

    # 3 BadJob at 2009-03-13
    create_and_process_jobs @worker, 3, Time.parse('2010-11-13'), BadJob
    # 3 BadJob by Jason at 2009-03-13
    create_and_process_jobs @worker, 3, Time.parse('2010-11-13'), BadJob, "Jason"

    # 7 BadJob at 2009-11-13
    create_and_process_jobs @worker, 7, Time.parse('2010-11-13'), BadJob
    # 7 BadJob by Freddy at 2009-11-13
    create_and_process_jobs @worker, 7, Time.parse('2010-11-13'), BadJob, "Freddy"

    # 11 BadJob at 2010-08-13
    create_and_process_jobs @worker, 11, Time.parse('2010-08-13'), BadJob
    # 11 BadJob by Jason at 2010-08-13
    create_and_process_jobs @worker, 11, Time.parse('2010-08-13'), BadJob, "Jason"

    @cleaner = Resque::Plugins::ResqueCleaner.new
  end

  test "#select returns failure jobs" do
    ret = @cleaner.select
    assert_equal 42, ret.size
  end

  test "#select works with a limit" do
    @cleaner.limiter.maximum = 10
    ret = @cleaner.select

    # only maximum number
    assert_equal 10, ret.size

    # latest one
    assert_equal Time.parse(ret[0]['failed_at']), Time.parse('2010-08-13')
  end

  test "#select with a block returns failure jobs which the block evaluates true" do
    ret = @cleaner.select {|job| job["payload"]["args"][0]=="Jason"}
    assert_equal 14, ret.size
  end

  test "#clear deletes failure jobs" do

  end

  test "#clear with a block deletes failure jobs which the block evaluates true" do

  end

  test "#requeue retries failure jobs" do

  end

  test "#requeue with a block retries failure jobs which the block evaluates true" do

  end

  test "#requeue_and_clear requeues and deletes failure jobs" do

  end

  test "#requeue_and_clear with a block requeues and deletes failure jobs which the block evaluates true" do

  end

  test "#clear_stale deletes failure jobs which is queued before the last x enqueued" do

  end

  test "#proc gives you handy proc definitions" do

  end
end
