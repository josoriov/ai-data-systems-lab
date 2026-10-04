# Data — incoming customer messages

`messages.jsonl` — one JSON object per line:

```json
{"id": "MSG-001", "channel": "chat | email | whatsapp", "received_at": "<ISO timestamp>", "from": "<sender>", "text": "<customer message, Spanish>"}
```

**All 340 messages are synthetic.** The illustrative design target is
**10,000 messages per day**. This sample demonstrates the processing flow;
it does not establish production throughput.

The messages are messy on purpose: mixed channels, informal Colombian Spanish, typos, some
multi-intent, some out of scope, and some pure noise.
