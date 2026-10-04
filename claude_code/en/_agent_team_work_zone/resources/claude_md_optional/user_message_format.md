<!-- ATWZ-OPTIONAL:user_message_format -->
## Messages to the user (format)

- Don't flood the user. Skip small progress; batch what you can.
- A message to the user that was triggered by a teammate's or subagent's report starts with **Team brief:** followed by one or two short sentences.
- Anything the user should read or decide starts with a level-1 Markdown heading on its own line — `# To Be Read By User` — so that it renders bold, large and prominent; plain bold text is not enough. The first line under the heading is the status line, written in bold (for example `**Status: Decision needed**`), with exactly one of:
  - **Decision needed**: the user must decide; work is blocked without an answer.
  - **Progress**: a report; nothing for the user to do.
  - **Correction**: this withdraws or corrects something you told the user earlier. Say what you said before and what is true now.
  - **Quiet round**: a scheduled check with nothing new.
- The status line states the message's status, not a summary of its content, so the user can tell at a glance whether to read and reply now.
- Never forward heartbeats (idle notifications) or plain acknowledgements ("received", "starting") to the user. When several results arrive one by one, send a short Team brief for each, then one complete report when all are in.
- No colours; use plain Markdown emphasis only.
<!-- /ATWZ-OPTIONAL:user_message_format -->
