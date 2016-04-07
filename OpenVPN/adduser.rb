#!/usr/bin/env ruby
# ---
# RightScript Name: Adduser
# Description: < Addes
# Inputs:
#   HASHED_PASSWORD:
#     Input Type: single
#     Category: Credentials
#     Required: True
#     Advanced: false
# Attachments: []
# ...

PASSWORD=ENV['HASHED_PASSWORD']

def create_qa_nightly_user()
  begin
    `sudo /bin/useradd -m qa_nightly -p #{PASSWORD}`
  rescue
    puts "unable to add user"
  end
end

create_qa_nightly_user
