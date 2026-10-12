# Governance package: Nordwind platform team

Fill in every TODO. This is what you take home.

## 1. Naming convention

Pattern: `nordwind.<domain>.<public|private>.<entity>.<event|state|command>`

Enforced by: TODO (what rejects a wrongly named topic, and where does it look for the name?)

## 2. Defaults at the broker

| Setting | Value | Why |
|---|---|---|
| `auto.create.topics.enable` | TODO | TODO |
| `num.partitions` | TODO | TODO |
| `default.replication.factor` | 3 | |
| `min.insync.replicas` | 2 | |

## 3. Limits per topic

Enforced by: TODO

| Rule | Value | The failure it prevents |
|---|---|---|
| Replicas at least | TODO | TODO |
| Partitions at most | TODO | TODO |
| `min.insync.replicas` | TODO | TODO |

## 4. Recommended client settings

We can only recommend these, the broker cannot enforce them.

| Setting | Recommendation | Why |
|---|---|---|
| `acks` (producer) | TODO | TODO |
| `enable.idempotence` (producer) | TODO | TODO |
| TODO | TODO | TODO |

## 5. Quotas

TODO (which clients, which limit, why)

## 6. How a team gets a topic

TODO (who asks whom, where, and what does the platform team check)

## 7. What we cannot prevent, and how we see it

| Failure | Prevention | What we see |
|---|---|---|
| A record the consumer cannot read | TODO | TODO |
| A team's application is too slow | TODO | TODO |
