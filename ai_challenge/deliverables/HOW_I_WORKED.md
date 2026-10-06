# How I worked — message triage

## Starting point

I made two decisions before asking an agent to write code. First, a wrong
automatic answer is more expensive than an unnecessary handoff. Second, the
model can interpret the message, but it should not have the last word on fraud,
account access, or policy coverage.

I read the taxonomy, the four policy files, and a sample of each kind of message.
That led me to add three in-scope reasons that were missing: application status,
product information, and service channels or hours. The knowledge base does not
answer them, so they go to CX instead of being labelled as unrelated.

Once that boundary was clear, I used coding agents to move faster. They profiled
the messages, drafted the Pydantic contract and API call, and suggested edge
cases. I made the final call on the taxonomy, routing, automatic-answer boundary,
reply text, and whether the output met the routing and grounding requirements.

## The instructions that shaped the solution

These are shortened versions of the three instructions I kept coming back to,
not a complete prompt log.

1. "Before writing code, compare the messages with the taxonomy and policies.
   Show me recurring Lumo topics that have no category or no safe answer."
   This produced the three taxonomy additions and kept policy gaps in scope.
2. "Let the model handle language, but put the risky decisions in one
   Python validation pass. Do not build a second keyword classifier."
   This became `apply_safety_rules`.
3. "Print every automatic reply and discarded row next to its source message.
   Look specifically for account-specific questions that received a general
   answer and for policy sections that do not answer the question."
   This final pass found cases that schema validation and unit tests had missed.

## Where the AI was wrong

The first code draft was much larger than the problem needed. It had a custom
HTTP client, several provider settings, duplicate validation paths, policy-slug
normalization, and a long keyword router. I replaced that with the official SDK,
one typed response, and one safety pass.

The model-written drafts were also not reliable enough. In an early probe, one
added a certificate type that the policy never mentioned. I stopped using its
wording: the model now selects policy sections, while the final customer text
comes from short reviewed templates.

The first complete run looked fine from the totals. It was not. Reading the
automatic and discarded rows next to the original messages exposed these
problems:

- `MSG-205` asked whether the customer's due date had changed. The first guard
  mistook "cambiaron" for a general request to "cambiar" the date and answered
  automatically. I changed the match to whole verbs and added the phrase to the
  offline cases.
- Current-balance certificates, failed certificate delivery, withholding
  certificates, unexplained charges, and bank-account or payment-link requests
  all need data or policy that is not available here. They now go to a person.
- One response cited the valid but unrelated prepayment section for a receipt
  question. The safety pass now rejects that section unless the message actually
  mentions prepayment. The receipt reply is rendered directly from the matching
  policy instead.
- Names in positive feedback were sometimes extracted as payment references.
  Discarded rows now have empty entities because none of those values can drive a
  downstream action.

I also removed the sender from model input after a probe used an email address
to personalize a draft. It was unnecessary and was not verified identity.

## Validation

I ran eight offline tests for invalid and duplicate input, mandatory-human
routing, account-specific and unsupported requests, policy-backed replies,
entity evidence, safe discards, summary reconciliation, and redacted error
rows.

I then ran the complete command and generated a side-by-side view of every
automatic and discarded result with its source text. On the recorded example run
that was 49 automatic replies and 33 discards. The issues above came from that review;
I fixed them, regenerated the batch, and checked those two sets again.

The final artifact contains all 340 input IDs in order and has no technical
errors. Automated checks and the safety pass ensure that:

- extracted entities occur in the source message;
- discarded rows do not retain irrelevant entities;
- automatic replies use policy text for every intent;
- only human escalations have queues;
- non-automatic results have no draft; and
- the summary totals reconcile with the rows.

The final split is 49 automatic replies, 258 escalations, and 33 discards. The
14% automation rate is conservative on purpose.

## What I would do next

The next useful step is a labelled holdout set, not more routing rules. I would
measure precision and recall per reason and track false automatic answers as the
main risk metric. After that I would choose the model and concurrency from
measured quality, latency, rate limits, and cost. For the illustrative target of
10,000 messages per day, the same per-message function can sit behind a queue; I would add that
infrastructure only once the integration requirements are known.
