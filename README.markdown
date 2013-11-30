ResqueCleaner [![Travis-CI](https://secure.travis-ci.org/ono/resque-cleaner.png?branch=master)](http://travis-ci.org/ono/resque-cleaner) [![Dependency Status](https://gemnasium.com/ono/resque-cleaner.png)](https://gemnasium.com/ono/resque-cleaner)
=============

[github.com/ono/resque-cleaner](https://github.com/ono/resque-cleaner)

Description
-----------

ResqueCleaner is a [Resque](https://github.com/defunkt/resque) plugin which
aims to help you to clean up failed jobs on Resque by:

* Showing stats of failed jobs
* Retrying failed jobs
* Removing failed jobs
* Filtering failed jobs


Installation
------------

Install as a gem:

    $ gem install resque-cleaner


Resque-Web integration
----------------------

![Screen 1](https://github.com/ono/resque-cleaner/raw/master/misc/resque-cleaner-main.png)
![Screen 2](https://github.com/ono/resque-cleaner/raw/master/misc/resque-cleaner-list.png)


Configuration
-------------

At first, you have to load ResqueCleaner to enable the Cleaner tab. Here is
an example step.

1. Create a configuration file for resque-web
<br/>```touch [app_dir]/config/resque-web.rb```

2. Add the following line into the file
<br/>```require 'resque-cleaner'```

3. Then pass the file when you start resque-web
<br/>```% resque-web [app_dir]/config/resque-web.rb```

You can also configure [limiter](https://github.com/ono/resque-cleaner#limiter)
and the retry option in the file.

e.g.

```ruby
require 'resque-cleaner'
module Resque::Plugins
  ResqueCleaner::Limiter.default_maximum = 10_000
  ResqueCleaner::Retry.default_config = true 
end
```

Console
-------

Hopefully a situation of your failed jobs is simple enough to get figured out through
the web interface. But, if not, a powerful filtering feature of ResqueCleaner may help
you to understand what is going on with your console(irb).

**Create Instance**

```ruby
    > cleaner = Resque::Plugins::ResqueCleaner.new
```

**Show Stats**

Shows stats of failed jobs grouped by date.

```ruby
    > cleaner.stats_by_date
    2009/03/13:    6
    2009/11/13:   14
    2010/08/13:   22
         total:   42
    => {'2009/03/10' => 6, ...}
```

You could also group them by class.

```ruby
    > cleaner.stats_by_class
         BadJob:    3
    HorribleJob:    7
          total:   10
    => {'BadJob' => 3, ...}
```

Or you could also group them by exception.

```ruby
    > cleaner.stats_by_exception
	 RuntimeError:   35
    SyntaxError:    7
          total:   42
    => {'RuntimeError' => 35, ...}
```

You can get the ones filtered with a block: it targets only jobs which the block
evaluates true.

e.g. Show stats only of jobs entered with some arguments:

```ruby
    > cleaner.stats_by_date {|j| j["payload"]["args"].size > 0}
    2009/03/13:    3
    2009/11/13:    7
    2010/08/13:   11
         total:   22
    => {'2009/03/10' => 3, ...}
```

**Retry(Requeue) Jobs**

You can retry all failed jobs with this method.

```ruby
    > cleaner.requeue
```

Of course, you can filter jobs with a block; it requeues only jobs which the
block evaluates true. 

e.g. Retry only jobs with some arguments:

```ruby
    > cleaner.requeue {|j| j["payload"]["args"].size > 0}
```

The job hash is extended with a module which defines some useful methods. You
can use it in the block.

e.g. Retry only jobs entered within a day:

```ruby
    > cleaner.requeue {|j| j.after?(1.day.ago)}
```

e.g. Retry EmailJob entered with arguments within 3 days:

```ruby
    > cleaner.requeue {|j| j.after?(3.days.ago) && j.klass?(EmailJob) && j["payload"]["args"].size>0}
```

See Helper Methods section bellow for more information.

NOTE:
[1.day.ago](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/numeric/time.rb)
is not in standard library. Using it for making explanation more understandable. It is equivalent to `Time.now - 60*60*24*3`.

**Clear Jobs**

You can clear all failed jobs with this method:

```ruby
    > cleaner.clear
```

Like you can do with the retry method, the clear method takes a block. Here are
some examples:

```ruby
    > cleaner.clear {|j| j.retried?}
    => clears all jobs already retried and returns number of the jobs.

    > cleaner.clear {|j| j.queue?(:low) && j.before?('2010-10-10')}
    => clears all jobs entried in :low queue before 10th October, 2010.

    > cleaner.clear {|j| j.exception?("RuntimeError") && j.queue?(:low)}
    => clears all jobs raised RuntimeError and queued :low queue
```

**Retry and Clear Jobs**

You can retry(requeue) and clear failed jobs at the same time; just pass true
as an argument. 

e.g. Retry EmailJob and remove from failed jobs:

```ruby
    > cleaner.requeue(true) {|j| j.klass?(EmailJob)}
```

**Retry with other queue**

You can requeue failed jobs into other queue. In this way, you can retry failed
jobs without blocking jobs being entered by your service running in the live.

e.g. Retry failed jobs on :retry queue

```ruby
    > cleaner.requeue(false, :queue => :retry)
```

Don't forget to launch resque worker for the queue.

    % QUEUE=retry rake resque:work

**Select Jobs**

You can just select the jobs of course. Here are some examples:

```ruby
    > cleaner.select {|j| j["payload"]["args"][0]=="Johonson"}
    > cleaner.select {|j| j.after?(2.days.ago)}
    > cleaner.select #=> returns all jobs
```

**Helper Methods**

Here is a list of methods a failed job retained through ResqueCleaner has:

    retried?: returns true if the job has already been retried.
    requeued?: alias of retried?.
    before?(time): returns true if the job failed before the time.
    after?(time): returns true if the job failed after the time.
    klass?(klass_or_name): returns true if the class of job matches.
    queue?(queue_name): returns true if the queue of job matches.
    exception?(exception_name): returns true if the exception matches.


Failed Job
-----------

Here is a sample of failed jobs:

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

Let's see how it works with an following example.

**Sample Situation**

* Number of failed jobs: 100,000

Default limiter is 1000 so that the limiter returns 1000 as a count.

```ruby
    > cleaner.limiter.count
    => 1,000
    > cleaner.failure.count
    => 100,000
```

You could know if the limiter is on with on? method.

```ruby
    > cleaner.limiter.on?
    => true
```

You can change the maximum number of the limiter with maximum attribute.

```ruby
    > cleaner.limiter.maximum = 3000
    => 3,000
    > cleaner.limiter.count
    => 3,000
    > cleaner.limiter.on?
    => true
```

With limiter, ResqueCleaner's filtering targets only the last X(3000 in this
sample) failed jobs.

```ruby
    > cleaner.select.size
    => 3,000
```

The clear\_stale method deletes all jobs entered prior to the last X(3000 in
this sample) failed jobs. This calls Redis API and no iteration occurs on Ruby
application; it should be quick even if there are huge number of failed jobs.

```ruby
    > cleaner.clear_stale
    > cleaner.failure.count
    => 3,000
    > cleaner.limiter.count
    => 3,000
    > cleaner.limiter.on?
    => false
```

Retry
-----

ResqueCleaner on default offers the option to retry failed jobs
without clearing them out of the failed jobs list. This can be handy to keep
track of when the same jobs have failed in the past, however, the retry option
can be turned off in order to limit your options to Clear or Clear and Retry.
By ensuring that every action includes the clearing of jobs, your list of failed
jobs is kept neat and less cluttered. It is also more obvious how many unique
failed jobs there are.

This option is configurable only in your application's configuration file for
resque-web, where `false` turns off the Retry option and `true` turns it on. 
The default value is true when not explicitly configured.
For example, the following will turn the Retry option off:

```ruby
require 'resque-cleaner'
module Resque::Plugins
  ResqueCleaner::Retry.default_config = false 
end
```

Many Thanks!
------------

To our [Contributors](https://github.com/ono/resque-cleaner/contributors)


