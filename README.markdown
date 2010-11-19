ResqueCleaner
==============

[github.com/ono/resque-cleaner](https://github.com/ono/resque-cleaner)


Description
-----------

ResqueCleaner is a [Resque](https://github.com/defunkt/resque) plugin which
helps you to deal with failed jobs on Resque by:

* Showing stats of failed jobs
* Retrying failed jobs
* Removing failed jobs
* Filtering failed jobs

Although ResqueCleaner has not integrated with Resque's web-based interface yet,
it is pretty easy to use on irb(console).


Installation
------------

Install as a gem:

    $ gem install resque-cleaner


Usage
-----

**Create Instance**

    > cleaner = Resque::Plugins::ResqueCleaner.new

**Show Stats**

Shows stats of failed jobs grouped by date.

    > cleaner.stats_by_date
    2009/03/13:    6
    2009/11/13:   14
    2010/08/13:   22
         total:   42
    => {'2009/03/10' => 6, ...}

You could also group them by class.

    > cleaner.stats_by_class
         BadJob:    3
    HorribleJob:    7
          total:   10
    => {'BadJob' => 3, ...}

You can get the ones filtered with a block: it targets only jobs which the block
evaluetes true.

e.g. Show stats only of jobs entried with some arguments:

    > cleaner.stats_by_date {|j| j["payload"]["args"].size > 0}
    2009/03/13:    3
    2009/11/13:    7
    2010/08/13:   11
         total:   22
    => {'2009/03/10' => 3, ...}

**Retry(Requeue) Jobs**

You can retry all failed jobs with this method.

    > cleaner.requeue

Of course, you can filter jobs with a block; it requeues only jobs which the
block evaluates true. 

e.g. Retry only jobs with some arguments:

    > cleaner.requeue{ |j| j["payload"]["args"].size > 0}

The job hash is extended with a module which defines some useful methods. You
can use it in the blcok.

e.g. Retry only jobs entried within a day:

    > cleaner.requeue {|j| j.after?(1.day.ago)}

e.g. Retry EmailJob entried with arguments within 3 days:

    > cleaner.requeue {|j| j["payload"]["args"]>0 && j.after?(3.days.ago) && j.klass?(EmailJob)}

See Helper Methods section bellow for more information.

NOTE:
[1.day.ago](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/numeric/time.rb)
is not in standard library. It is equivalent to `Time.now - 60*60*24*3`.

**Clear Jobs**

You can clear all failed jobs with this method:

    > cleaner.clear

Like you can do with the retry method, the clear metod takes a block. Here are
some examples:

    > cleaner.clear {|j| j.retried?}
    => clears all jobs already retried and returns number of the jobs.

    > cleaner.clear {|j| j.queue?(:low) && j.before?('2010-10-10')}
    => clears all jobs entried in :low queue before 10th October, 2010.

    > cleaner.clear {|j| j["exception"]=="RuntimeError" && j.queue?(:low)}
    => clears all jobs raised RuntimeError and queued :low queue

**Retry and Clear Jobs**

You can retry(requeue) and clear failed jobs at the same time; just pass true
as an argument. e.g. Retry EmailJob and remove from failed jobs.

    > cleaner.requeue(true) {|j| j.klass?(EmailJob)}

**Select Jobs**

You can just select the jobs of course. Here are some examples:

    > cleaner.select {|j| j["exception"]=="RuntimeError"}
    > cleaner.select {|j| j.after?(2.days.ago)}
    > cleaner.select #=> returns all jobs

**Helper Methods**

Here is a list of methods a job extended:

    retried?: returns true if the job has already been retried.
    requeued?: alias of retried?.
    before?(time): returns true if the job failed before the time.
    after?(time): returns true if the job failed after the time.
    klass?(klass_or_name): returns true if the class of job matches.
    queue?(queue_name): returns true if the queue of job matches.


Failed Job
-----------

I show a sample of failed job bellow; it might help you when you write a block for
filtering failed jobs.

    {"failed_at": "2009/03/13 00:00:00",
     "payload": {"args": ["Johnson"], "class": "BadJob"},
     "queue": "jobs",
     "worker": "localhost:7327:jobs,jobs2",
     "exception": "RuntimeError",
     "error": "Bad job, Johnson",
     "backtrace": 
      ["./test/test_helper.rb:108:in `perform'",
       "/opt/local/lib/ruby/gems/1.8/gems/resque-1.10.0/lib/resque/job.rb:133:in `perform'",
       "/opt/local/lib/ruby/gems/1.8/gems/resque-1.10.0/lib/resque/worker.rb:157:in `perform'",
       "/opt/local/lib/ruby/gems/1.8/gems/resque-1.10.0/lib/resque/worker.rb:124:in `work'",
       "....(omitted)....",
       "./test/test_helper.rb:41",
       "test/resque_cleaner_test.rb:3"]
    }


Limiter
-------

ResqueCleaner expects a disaster situation like a huge number of failed jobs are
out there. Since ResqueCleaner's filter function is running on your application
process but on your Redis, it would not respond ages if you try to deal with all
of those jobs.

ResqueCleaner supposes recent jobs are more important than old jobs. Therefore
ResqueCleaner deals with **ONLY LAST X(default=1000) JOBS**. In this way, you
could avoid slow responses. You can change the number through `limiter` attribute.

Let's see how it works with an follwing example.

**Sample Situation**

* Number of failed jobs: 100,000

Default limiter is 1000 so that the limiter returns 1000 as a count.

    > cleaner.limiter.count
    => 1,000
    > cleaner.failure.count
    => 100,000

You could know if the limiter is on with on? method.

    > cleaner.limiter.on?
    => true

You can change the maximum number of the limiter with maximum attribute.

    > cleaner.limiter.maxmum = 3000
    => 3,000
    > cleaner.limiter.count
    => 3,000
    > cleaner.limiter.on?
    => true

With limiter, ResqueClener's filtering targets only the last X(3000 in this
sampe) failed jobs.

    > cleaner.select.size
    => 3,000

The clear\_stale method deletes all jobs entried prior to the last X(3000 in
this sample) failed jobs. This calls Redis API and no iteration occurs on Ruby
application; it should be quick even if there are huge number of failed jobs.

    > cleaner.clear_stale
    > cleaner.failure.count
    => 3,000
    > cleaner.limiter.count
    => 3,000
    > cleaner.limiter.on?
    => false

TODO
----

* Integration with Resque's sinatra based front end.
* More stats.

Any suggestion or idea are welcomed.

