# hash-record - skill index

Content-hash-keyed durable record store used by consumer skills for caching audit, review, and hygiene results.

## hash-record

Defines the Probe / Read / Write / Invalidate API and path conventions for the .hash-record/ store.

## hash-record-check

Probes the hash-record cache for a single file, returning a HIT or MISS with the canonical record path.

## hash-record-index

Builds and refreshes manifest.yaml index files inside each hash directory under .hash-record/.

## hash-record-manifest

Computes a deterministic manifest hash for a set of files, producing a multi-file cache key.

## hash-record-prune

Removes orphaned hash directories from a repository's .hash-record/ store.

## hash-record-rekey

Re-keys a stale hash-record entry after a file's content changes, moving the record to the new blob hash path via git mv.
