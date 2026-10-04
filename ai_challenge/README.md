# Customer-message triage

A prototype for classifying synthetic Spanish support messages for **Lumo**, a
fictional consumer-lending company. The [project brief](../PROJECT_BRIEF.md)
defines the goals and expected input/output contracts.

The planned input is a batch of 340 messages across chat, email, and WhatsApp.
Each result should record contact reasons, urgency, evidence-backed entities,
an action, a human queue where needed, and a grounded Spanish reply when safe.
Processing failures should remain visible in the output and batch summary.

The model will interpret language; Python rules will enforce mandatory human
handling and policy coverage. Fraud, account lookups, and unsupported actions
require a person. Fictional policy examples will intentionally leave some
requests unanswered to exercise these boundaries.

The illustrative scale target is 10,000 messages/day. This is a design scenario,
not measured throughput. The initial scope is a local prototype with offline
checks; deployment and labelled model evaluation are separate work.
