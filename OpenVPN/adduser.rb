#!/usr/bin/env ruby

# ---
# RightScript Name: Adds qa_nightly user
# Description: < Adds required qa_nightly user for jump boxes
# Inputs:
#   HASHED_PASSWORD:
#     Input Type: single
#     Category: Credentials
#     Required: True
#     Advanced: false
# Attachments: []
# ...

password = ENV['HASHED_PASSWORD']

def create_qa_nightly_user
  `sudo /bin/useradd -m qa_nightly -p #{PASSWORD}`
rescue
  puts 'unable to add user'
end

create_qa_nightly_user(password)
