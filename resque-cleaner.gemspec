Gem::Specification.new do |s|
  s.name              = "resque-cleaner"
  s.version           = "0.2.2"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "Resque plugin cleaning up failed jobs."
  s.homepage          = "http://github.com/ono/resque-cleaner"
  s.email             = "ononoma@gmail.com"
  s.authors           = [ "Tatsuya Ono" ]

  s.files             = %w( README.markdown CHANGELOG.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")

  s.require_paths     = ["lib"]

  s.extra_rdoc_files  = [ "LICENSE", "README.markdown", "CHANGELOG.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency "resque", "~> 1.0"

  s.description = <<DESCRIPTION
    Resque helper plugin cleaning up failed jobs with some neat features such as filtering, retrying, removing and showing stats.
DESCRIPTION
end

