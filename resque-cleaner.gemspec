Gem::Specification.new do |s|
  s.name              = "resque-cleaner"
  s.version           = "0.0.1"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "A Resque plugin cleaning up failure jobs."
  s.homepage          = "http://github.com/ono/resque-cleaner"
  s.email             = "ononoma@gmail.com"
  s.authors           = [ "Tatsuya Ono" ]

  s.files             = %w( README.markdown Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")

  s.require_paths     = ["lib"]

  s.extra_rdoc_files  = [ "LICENSE", "README.markdown" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency "resque", "~> 1.0"

  s.description = <<DESCRIPTION
    ResqueCleaner is a Resque plugin which helps you clean up failure jobs. It provides the following functionalities.

    * Filters failure jobs with an easy and extensible way
    * Retries failure jobs
    * Removes failure jobs
    * Shows stats

DESCRIPTION
end

