#!/usr/bin/env ruby

PASSWORD=ENV['hashed_password']

def create_qa_nightly_user()
  begin
    `sudo /bin/useradd -m qa_nightly -p #{PASSWORD}`
  rescue
    puts "unable to add user"
  end
end

create_qa_nightly_user
