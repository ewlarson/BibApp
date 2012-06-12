require 'bundler/capistrano'
require 'tmpdir'
require 'fileutils'

set :production_server, "sophia.cites.illinois.edu"
set :test_server, "athena.cites.illinois.edu"
set :new_test_server, "saga-dev.cites.illinois.edu"
set :new_production_server, "saga.cites.illinois.edu"
default_run_options[:shell] = '/bin/bash -l'

desc 'Set prerequisites for deployment to production server.'
task :production do
  role :web, production_server
  role :app, production_server
  role :db, production_server, :primary => true
  before 'deploy:update_code', 'deploy:rsync_ruby'
end

desc 'Set prerequisites for deployment to test(staging) server.'
task :staging do
  role :web, test_server
  role :app, test_server
  role :db, test_server, :primary => true
#  set :branch, 'uiuc-connections-omni-shib'
  set :branch, 'uiuc-connections'
end

task :new_staging do
  role :web, new_test_server
  role :app, new_test_server
  role :db, new_test_server, :primary => true
end

task :new_production do
  role :web, new_production_server
  role :app, new_production_server
  role :db, new_production_server, :primary => true
  #TODO need to do a sync here, but wait to write until we have server
end

#set this if you want to reindex or to redeploy a new copy of the solr installation (e.g. after a schema change)
#e.g. cap staging reindex deploy
task :reindex do
  set :reindex, true
end

set :application, "Bibapp"

set :rails_env, ENV['RAILS_ENV'] || 'production'

set :scm, :git
set :repository, 'git://github.com/BibApp/BibApp.git'
set :branch, 'new-uiuc-connections' unless fetch(:branch, nil)
set :deploy_via, :remote_cache

#directories on the server to deploy the application
#the running instance gets links to [deploy_to]/current
set :home, "/services/ideals-bibapp"
set :deploy_to, "#{home}/bibapp-capistrano"
set :current, "#{deploy_to}/current"
set :shared, "#{deploy_to}/shared"
set :shared_config, "#{shared}/config"
set :public, "#{current}/public"

set :user, 'ideals-bibapp'
set :use_sudo, false

namespace :deploy do
  task :start do
    ;
  end
  task :stop do
    ;
  end
  task :restart, :roles => :app, :except => {:no_release => true} do
    run "touch #{current}/tmp/restart.txt"
  end

  desc "create a config directory under shared"
  task :create_shared_dirs do
    run "mkdir #{shared}/config"
    [:attachments, :groups, :people].each do |dir|
      run "mkdir #{shared}/system/#{dir}"
    end
  end

  desc "link shared configuration"
  task :link_config do
    ['database.yml', 'ldap.yml', 'personalize.rb', 'smtp.yml',
     'solr.yml', 'sword.yml', 'oauth.yml', 'open_id.yml', 'locales.yml', 'keyword_exclusions.yml', 'stopwords.yml'].each do |file|
      run "ln -nfs #{shared_config}/#{file} #{current}/config/#{file}"
    end
    run "ln -nfs #{shared_config}/personalize/*.yml #{current}/config/locales/personalize/."
  end

  desc "symlink shared subdirectories of public"
  task :symlink_shared_dirs do
    [:attachments, :sherpa].each do |dir|
      run "ln -fs #{public}/system/#{dir} #{public}/#{dir}"
    end
  end

  #Since we can't build on the production server we have to copy the ruby and bundle gems from the test server.
  #Note that this does mean that a lot of stale gems may accumulate over time.
  #For the test server, when we move to the new servers, and assuming that we use rvm, the standard procedure should suffice to clear out
  #gems directly associated with the ruby (clear and rebuild the gemset).
  #For the shared bundle, make sure the latest code is installed and then move the capistrano shared/bundle and run
  #cap staging bundle:install. Assuming that is fine the old bundle can be removed
  #For the production server, you'll have to remove the local cache and also the target directories on the production
  #server. Then run this and everything should be copied over.
  #That said, I think by preserving the local copy, instead of having it in /tmp, should really render weeding the old
  #gems out into an optional activity. (Of course, bundler and rvm help with this as well.)
  desc "rsync the ruby directory from the test server to the production server"
  task :rsync_ruby do
    ruby_dir = "/home/hading/cache/bibapp/ruby/"
    bundle_dir = "/home/hading/cache/bibapp/bundle/"
    system "rsync -avPe ssh #{user}@#{test_server}:#{home}/ruby/ #{ruby_dir}"
    system "rsync -avPe ssh #{user}@#{test_server}:#{shared}/bundle/ #{bundle_dir}"
    system "rsync -avPe ssh #{ruby_dir} #{user}@#{production_server}:#{home}/ruby/"
    system "rsync -avPe ssh #{bundle_dir} #{user}@#{production_server}:#{shared}/bundle/"
  end

end

namespace :bibapp do
  [:stop, :start, :restart].each do |action|
    desc "#{action} Bibapp services"
    task action do
      begin
        run "cd #{current}; RAILS_ENV=#{rails_env} bundle exec rake bibapp:#{action}"
      rescue
        puts "Current directory doesn't exist yet"
      end
    end
  end
end

#The sleep is to make sure that solr has enough time to start up before
#running this.
namespace :solr do
  desc "Reindex solr"
  task :refresh_index do
    run "cd #{current}; sleep 10; RAILS_ENV=#{rails_env} bundle exec rake solr:refresh_index"
  end

  set :index_dir, "#{current}/vendor/bibapp-solr/"
  set :backup_dir, "/tmp/bibapp-solr-backup/"

  desc "Save the current solr index to a temporary location"
  task :save_index do
    run "rm -rf #{backup_dir}"
    run %Q(mv #{index_dir} #{backup_dir})
  end

  desc "Restore the previous solr index from a temporary location"
  task :restore_index do
    run "rm -rf #{index_dir}"
    run %Q(mv #{backup_dir} #{index_dir})
  end

end

after 'deploy:setup', 'deploy:create_shared_dirs'

before 'deploy:update', 'bibapp:stop'
before 'deploy:update' do
  unless exists?(:reindex)
    find_and_execute_task('solr:save_index')
  end
end

after 'deploy:update', 'deploy:link_config'
after 'deploy:update', 'deploy:symlink_shared_dirs'
after 'deploy:update' do
  unless exists?(:reindex)
    find_and_execute_task('solr:restore_index')
  end
end

after 'deploy:start', 'bibapp:start'
after 'deploy:stop', 'bibapp:stop'
after 'deploy:restart', 'bibapp:restart'

after 'bibapp:start' do
    if exists?(:reindex)
      find_and_execute_task('solr:refresh_index')
    end
end
after 'bibapp:restart' do
    if exists?(:reindex)
      find_and_execute_task('solr:refresh_index')
    end
end

#if exists?(:reindex)
#  after 'bibapp:start', 'solr:refresh_index'
#  after 'bibapp:restart', 'solr:refresh_index'
#end
