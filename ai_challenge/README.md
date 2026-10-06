# Customer-message triage

A Python prototype that classifies synthetic Spanish support messages for
**Lumo**, a fictional consumer-lending company. It combines structured model
output with deterministic rules for evidence, human routing, and policy-grounded
replies. See the [project brief](../PROJECT_BRIEF.md) for the wider context.

## Input and output

The [input dataset](data/README.md) contains 340 JSONL messages across chat,
email, and WhatsApp. It includes informal language, multiple intents, ambiguous
requests, and noise.

Each result records the primary and secondary contact reasons, priority,
extracted entities, action, human queue where applicable, policy references,
and a Spanish draft when automatic handling is supported. Technical failures
remain visible as error rows. A batch summary reconciles the per-message results.

## Decision boundaries

- The model interprets messages against the [contact taxonomy](taxonomy.md).
- Python verifies entity evidence and applies mandatory-human routing rules.
- Fraud, account lookups, unsupported policies, and actions requiring identity
  validation go to a person.
- Automatic drafts come from reviewed templates grounded in the
  [fictional knowledge base](knowledge_base/README.md).
- The sender field is omitted from model input. Message text is still sent to
  the provider and can contain synthetic personal identifiers.

## Run, test, and inspect

The [implementation guide](deliverables/README.md) includes setup, live execution
with your own API key, and offline test commands. The
[example output](deliverables/outputs/triage_results.json) records 49 automatic
replies, 258 human escalations, and 33 discards with no technical errors. These
counts describe the recorded run and do not establish classification accuracy.

[Development notes](deliverables/HOW_I_WORKED.md) explain AI-assisted work,
corrections made during review, and validation of the routing boundaries.

## Scale and limitations

The illustrative design target is 10,000 messages/day. The sample run does not
demonstrate that capacity. A deployment would need a labelled evaluation set,
provider quota and load testing, and decisions about retention and redaction.
The policy examples have intentional gaps, so conservative human handoff is
part of the design.
