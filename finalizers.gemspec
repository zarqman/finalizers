require_relative "lib/finalizers/version"

Gem::Specification.new do |spec|
  spec.name        = "finalizers"
  spec.version     = Finalizers::VERSION
  spec.authors     = ["thomas morgan"]
  spec.email       = ["tm@iprog.com"]
  spec.homepage    = "https://github.com/zarqman/finalizers"
  spec.summary     = "Adds finalizers to ActiveRecord models"
  spec.description = "Adds finalizers to ActiveRecord models to clean up both database child dependencies and external resources (APIs, etc). Finalizers run in background jobs and are fully retryable."
  spec.license     = "MIT"

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => 'https://github.com/zarqman/finalizers/blob/master/CHANGELOG.md'
  }

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end

  spec.add_dependency 'rails', '>= 7'
  spec.add_dependency 'rescue_like_a_pro', '~> 1'
end
