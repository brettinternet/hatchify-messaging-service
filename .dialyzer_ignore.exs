[
  # Messages.validate_message/1 can succeed with valid payloads despite dialyzer's analysis 
  {"lib/messaging_web/controllers/message.ex", :pattern_match, 86},
  
  # Message.validate_changeset/2 function exists and works correctly
  {"lib/messaging/messages.ex", :call, 25}
]