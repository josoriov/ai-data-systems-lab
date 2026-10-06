# Lumo message triage

This is a working prototype for classifying incoming customer messages. It
identifies the contact reason, extracts useful details, and decides whether the
message can receive a policy-backed reply or needs a person.

I use the model for the part it is good at—understanding messy Spanish—and keep
the high-risk routing and reply rules in Python.

## Run

From this directory, use `uv`, copy `.env.example` to `.env`, add your own
OpenAI API key, and run:

```sh
./run.sh
```

The script creates a Python 3.13 `.venv` with `uv` if needed, installs the
pinned direct dependencies, reads `../data/messages.jsonl`, and writes
`outputs/triage_results.json`.

The paths and worker count are optional:

```sh
./run.sh --input ../data/messages.jsonl --output outputs/result.json --workers 4
```

The default is eight workers. Messages are still written in input order.

## Design

There are only three implementation files:

- `triage.py` has the schemas, prompt, model call, safety rules, batch runner,
  and summary;
- `test_triage.py` checks the business boundaries without calling the API; and
- `run.sh` is the setup-and-run entry point.

The taxonomy and four policy files are included in the model instructions. Each
message is processed separately using the Responses API and Pydantic Structured
Outputs. The typed response is useful, but it is not the final decision. A
deterministic pass then checks that:

1. extracted values occur in the original text;
2. fraud, account lookups, unsupported requests, and actions for a customer go
   to the right human queue;
3. only noise, unrelated messages, and positive feedback can be discarded;
4. an automatic answer has a policy section for every detected intent; and
5. the final reply comes from reviewed policy wording, not model-written prose.

A failed API request becomes an error row with the original message ID. It does
not disappear from the batch.

## Data handling

The API call sets `store=False` and does not send the `from` field because the
sender is not needed for classification. The message text is sent to the model,
and that text can itself contain document numbers or other personal data. The
sample is synthetic; a real rollout would still need an approved provider,
retention policy, and a decision on whether those values should be redacted
before the call.

## Test

From this directory, create the environment and install dependencies without
calling the model:

```sh
test -x .venv/bin/python || uv venv --python 3.13 .venv
uv pip install --python .venv/bin/python -r requirements.txt
.venv/bin/python -m unittest -v
```

The seven tests need no API key or network access once dependencies are installed.
Live triage calls incur provider usage and send the message text to the API.

## Limits of this prototype

I do not have labelled data, so the manual batch review is not a substitute for
precision and recall. The keyword guards are intentionally conservative and
cover the risks found in this sample; they are not meant to grow into a large
rules engine. I also did not test provider quotas or backpressure at the
illustrative design volume. Those should be measured before putting the
function behind a queue.
