---
# swarm built-in personality registry
# Authoritative source of personality metadata for swarm dispatch.
# Add a personality: append entry here + drop body file at reviewers/<kebab-name>.md.
# Custom Specialist has no body file — generated on-the-fly by swarm.
---

- name: Devil's Advocate
  trigger: always
  required: true
  suggested_models: [sonnet-class, gpt-class]
  suggested_backends: [dispatch-sonnet]
  scope: Challenge assumptions, surface what could go wrong, find blind spots in the artifact's reasoning. No constructive design suggestions — adversarial role only. Cite evidence per finding or retract.
  vendor: openai

- name: Security Auditor
  trigger: problem touches authentication, user input, API endpoints, data access, secrets, network calls, file system writes, or process execution
  required: false
  suggested_models: [sonnet-class]
  suggested_backends: [dispatch-sonnet]
  scope: Identify vulnerabilities in the artifact under review. No design advice, no performance commentary, no style guidance — security only. Cite the specific code/config/scenario that creates the vulnerability per finding.
  vendor: anthropic

- name: Custom Specialist
  trigger: no built-in or caller-supplied personality covers the inferred problem domain (e.g. cooking, civil engineering, music theory, etc.)
  required: false
  suggested_models: [sonnet-class]
  suggested_backends: [dispatch-sonnet]
  scope: Generated on-the-fly. Role and scope inferred from the problem domain. Body file does not exist; system prompt synthesized inline at dispatch time. Same read-only and evidence-citation constraints as registered personalities. One-shot — never persisted.
  vendor: anthropic
