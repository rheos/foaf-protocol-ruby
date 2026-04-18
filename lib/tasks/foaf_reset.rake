namespace :foaf do
  desc "Wipe and reseed the testnet database. Refuses to run on production."
  task :reset_testnet => :environment do
    network = ENV["FOAF_NETWORK"]
    db_url  = ENV["DATABASE_URL"].to_s

    unless network == "testnet"
      abort "REFUSED: FOAF_NETWORK is '#{network.inspect}', not 'testnet'. Reset aborted."
    end

    unless db_url.include?("foaf_testnet")
      abort "REFUSED: DATABASE_URL does not contain 'foaf_testnet'. Reset aborted."
    end

    puts "[reset] Wiping foaf_testnet database..."
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    puts "[reset] Done. Database is empty and migrated."
  end
end
