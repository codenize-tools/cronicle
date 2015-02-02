require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new('spec')
task :default => :spec

namespace :vagrant do
  task :up do
    sh 'vagrant up'
  end

  task :destroy do
    sh 'vagrant destroy -f'
  end
end
