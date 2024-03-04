Gem::Specification.new do |s|
  s.name              = "resque-cleaner"
  s.version           = "0.5.0"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "Resque plugin cleaning up failed jobs."
  s.homepage          = "https://github.com/ono/resque-cleaner"
  s.email             = "ononoma@gmail.com"
  s.authors           = [ "Tatsuya Ono" ]
  s.license           = "MIT"
  s.required_ruby_version = '>= 1.9.3'

  s.files             = %w( README.md CHANGELOG.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")

  s.require_paths     = ["lib"]

  s.extra_rdoc_files  = [ "LICENSE", "README.md", "CHANGELOG.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency "resque"

  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "rack-test", "~> 0.6.0"

  s.description = <<DESCRIPTION
    resque-cleaner maintains the cleanliness of failed jobs on Resque.
DESCRIPTION
end

