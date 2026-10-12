Gem::Specification.new do |s|
  s.name              = "resque-cleaner"
  s.version           = "0.5.0"
  s.summary           = "Resque plugin cleaning up failed jobs."
  s.homepage          = "https://github.com/ono/resque-cleaner"
  s.email             = "ononoma@gmail.com"
  s.authors           = [ "Tatsuya Ono", "Patrick Tulskie" ]
  s.license           = "MIT"
  s.required_ruby_version = '>= 3.2'

  s.metadata = {
    "changelog_uri"         => "https://github.com/ono/resque-cleaner/blob/master/CHANGELOG.md",
    "source_code_uri"       => "https://github.com/ono/resque-cleaner",
    "rubygems_mfa_required" => "true"
  }

  s.files             = %w( README.md CHANGELOG.md LICENSE )
  s.files            += Dir.glob("lib/**/*")

  s.require_paths     = ["lib"]

  s.extra_rdoc_files  = [ "LICENSE", "README.md", "CHANGELOG.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency "resque", ">= 2.0"

  s.description = <<DESCRIPTION
    resque-cleaner maintains the cleanliness of failed jobs on Resque.
DESCRIPTION
end
