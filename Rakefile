task :default => [:test]

desc "Run cucumber tests for sql_mapper against sqlite, postgres and mysql"
task :test do
  puts `cucumber features`
end

namespace :db do
  desc "Drop the postgres and mysql test databases"
  task :drop do
    puts `psql -U postgres -c "drop database sql_mapper_test"`
    puts `mysql -u root -e "drop database sql_mapper_test"`
  end

  desc "Create the postgres and mysql test databases"
  task :create do
    puts `psql -U postgres -c "create database sql_mapper_test"`
    puts `mysql -u root -e "create database sql_mapper_test"`
  end
end
