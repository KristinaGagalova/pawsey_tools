#!/usr/bin/env bash
# find_best_mem_node.sh
#
# Utility to suggest a fast interactive SRUN command on SLURM.
# It inspects nodes across the partitions you can use, ranks them by free memory,
# and then suggests an `srun` that lets the scheduler pick any suitable node
# (i.e., it does NOT pin to a specific host, to avoid long queue times).
#
# Usage:
#   ./find_best_mem_node.sh [PARTITION] [ACCOUNT] [MEM_REQ] [WALLTIME] [--run]
#
# Examples:
#   ./find_best_mem_node.sh
#   ./find_best_mem_node.sh work
#   ./find_best_mem_node.sh highmem pawsey1142 300G 02:00:00 --run
#
# Arguments:
#   PARTITION   (optional) restrict to a specific partition, e.g. "work" or "highmem"
#   ACCOUNT     SLURM account to charge (default: pawsey1142)
#   MEM_REQ     requested memory for the job (default: 20G)
#   WALLTIME    requested time limit (default: 04:00:00)
#   --run       if given, immediately executes srun with the suggested options
#
# Requirements:
#   - SLURM utilities available: sinfo, sacctmgr, scontrol, srun
#   - Bash >= 4 (for mapfile, arrays)
#
# Exit codes:
#   1 → No partitions/nodes found or no partition chosen
#   2 → Best node not in requested partition (informational guard; unlikely used without -w)
#

set -euo pipefail

# --- Parse CLI arguments with defaults ---
PARTITION_OPT="${1:-}"              # optional fixed partition
ACCOUNT="${2:-pawsey1142}"          # default account
MEM_REQ="${3:-20G}"                # default memory request
WALLTIME="${4:-04:00:00}"           # default walltime
RUN_NOW="${5:-}"                    # optional flag --run

# --- Helper: get allowed partitions for this user/account ---
get_allowed_parts() {
  # Preferred: list partitions tied to the account using sacctmgr
  if PARTS_RAW=$(sacctmgr -nP show assoc user="$USER" account="$ACCOUNT" format=partition 2>/dev/null | tr '|' '\n'); then
    :
  else
    # Fallback: ask SLURM for all visible partitions; strip the "*" marker on default
    PARTS_RAW=$(sinfo -h -o "%P" | sed 's/*//g')
  fi
  # Clean up: remove (null), split on commas, unique sort
  printf "%s\n" "$PARTS_RAW" \
    | sed 's/(null)//g' \
    | tr ',' '\n' \
    | awk 'NF' \
    | sort -u
}

# --- Step 1: Determine partitions to consider ---
declare -a PARTS
if [ -n "$PARTITION_OPT" ]; then
  PARTS=("$PARTITION_OPT")
  # Warn if the requested partition is not in your associations (when sacctmgr is available)
  if sacctmgr --version >/dev/null 2>&1; then
    if ! get_allowed_parts | grep -qx "$PARTITION_OPT"; then
      echo "Warning: partition '$PARTITION_OPT' not listed in your associations for $ACCOUNT. Continuing anyway…"
    fi
  fi
else
  mapfile -t PARTS < <(get_allowed_parts)
fi

if [ "${#PARTS[@]}" -eq 0 ]; then
  echo "No partitions found to consider."
  exit 1
fi

echo "Partitions considered:"
printf '  - %s\n' "${PARTS[@]}"
echo

# --- Step 2: List all nodes in chosen partitions (one hostname per line) ---
NODES_TMP=$(mktemp)
: > "$NODES_TMP"
for p in "${PARTS[@]}"; do
  # -N lists nodes, -p filters by partition, -o "%N" prints only node names
  sinfo -h -N -p "$p" -o "%N" || true
done | awk 'NF' | sort -u > "$NODES_TMP"

if [ ! -s "$NODES_TMP" ]; then
  echo "No nodes visible in chosen partitions."
  rm -f "$NODES_TMP"
  exit 1
fi

# --- Step 3: Inspect nodes and compute free memory ---
OUT=$(mktemp)
# Print header row
printf "%-12s %-10s %-10s %-10s %-10s %-30s\n" "Node" "RealMB" "AllocMB" "FreeMB" "ScoreMB" "A_Partitions" > "$OUT"

# Loop through nodes and collect Real/Alloc/Free memory
while read -r node; do
  line=$(scontrol -o show node "$node" 2>/dev/null || true)
  [ -z "$line" ] && continue
  awk -v ln="$line" -v node="$node" '
    BEGIN{
      n=split(ln,a," ");
      for(i=1;i<=n;i++){
        split(a[i],kv,"="); k=kv[1]; v=kv[2];
        if(k=="RealMemory") rm=v;
        else if(k=="AllocMem") am=v;
        else if(k=="FreeMem")  fm=v;
        else if(k=="Partitions") pt=v;
      }
      if(rm=="") rm=0;
      if(am=="") am=0;
      if(fm==""){ fm=rm - am }   # fallback if FreeMem is hidden
      if(fm<0) fm=0;             # guard against negative fallback
      score=fm+0;                # simple score: higher free memory is better
      printf "%-12s %-10s %-10s %-10s %-10s %-30s\n", node, rm, am, fm, score, pt;
    }' >> "$OUT"
done < "$NODES_TMP"

# Print top nodes sorted by free memory
echo "=== Top nodes by free memory (within chosen partitions) ==="
# Guard with "|| true" to avoid SIGPIPE errors under 'set -euo pipefail'
column -t "$OUT" | (read -r header; echo "$header"; sort -k5,5nr | head -n 16) || true
echo

# --- Step 4: (Optional) pick the "best" node to infer a good partition ---
# We no longer pin to a specific node, but we can still pick a reasonable partition
# (e.g., the first partition listed for the top-scoring node) when user didn't specify one.

BEST_NODE=""
BEST_PARTS=""
BEST_SCORE=-1

while IFS= read -r line; do
  # skip header
  if [[ "$line" == Node* ]]; then continue; fi
  # extract fields
  read -r node real alloc free score parts <<<"$line" || true
  # choose the node with maximum score
  if [[ "${score:-}" =~ ^[0-9]+$ ]]; then
    if (( score > BEST_SCORE )); then
      BEST_SCORE="$score"
      BEST_NODE="$node"
      BEST_PARTS="${parts:-}"
    fi
  fi
done < "$OUT"

if [ -z "${BEST_NODE:-}" ]; then
  echo "Could not determine a best node."
  head -n 5 "$OUT" >&2
  rm -f "$NODES_TMP" "$OUT"
  exit 1
fi

# Choose the partition
if [ -n "$PARTITION_OPT" ]; then
  # If the user requested a partition, keep it.
  BEST_PART="$PARTITION_OPT"
else
  # Otherwise, default to the first listed partition for the top node.
  BEST_PART="${BEST_PARTS%%,*}"
  BEST_PART="${BEST_PART%% *}"
fi

if [ -z "${BEST_PART:-}" ]; then
  echo "Could not determine a partition to use."
  rm -f "$NODES_TMP" "$OUT"
  exit 1
fi

# Report the chosen partition (and show the top node for context)
echo "Selected: partition=$BEST_PART  (top-free-mem node observed: $BEST_NODE)  account=$ACCOUNT  mem=$MEM_REQ  time=$WALLTIME"
echo

# --- Step 5: Print suggested SRUN command (NO host pinning; let scheduler decide) ---
echo "Suggested command (multi-line):"
cat <<EOF
srun \\
  -N 1 -n 1 \\
  --partition=${BEST_PART} \\
  --account=${ACCOUNT} \\
  --time=${WALLTIME} \\
  --pty bash -i
EOF
echo
echo "One-liner:"
echo "srun -N 1 -n 1 --partition=${BEST_PART} --account=${ACCOUNT} --time=${WALLTIME} --pty bash -i"
echo

# --- Step 6: Optionally execute immediately ---
if [ "${RUN_NOW:-}" = "--run" ]; then
  echo "Running now..."
  exec srun -N 1 -n 1 --partition="${BEST_PART}" --account="${ACCOUNT}" --time="${WALLTIME}" --pty bash -i
fi

# --- Cleanup ---
rm -f "$NODES_TMP" "$OUT"
