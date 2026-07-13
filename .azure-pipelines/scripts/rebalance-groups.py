#!/usr/bin/env python3
"""
Analyze Azure DevOps Pipeline logs from nightly CI runs and propose
a test group reorganization where:
  - Group 1 contains all modules that have action plugins
  - Remaining groups distribute tests to fit within ~45 min timeout

Usage:
    python3 regroup_tests.py [--log-dir azp-logs] [--targets-dir tests/integration/targets]
                             [--action-dir plugins/action] [--max-minutes 45]
                             [--max-groups 4] [--apply]
"""

import argparse
import os
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path


TIMESTAMP_RE = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+)Z')
TARGET_RE = re.compile(r'Running (\S+) integration test role')
TEARDOWN_RE = re.compile(r'PLAY \[Teardown Windows code coverage')
FINISHING_RE = re.compile(r'##\[section\]Finishing: Run Tests')


def parse_timestamp(ts_str):
    if '.' in ts_str:
        base, frac = ts_str.split('.')
        frac = frac[:6]
        ts_str = f"{base}.{frac}"
    return datetime.fromisoformat(ts_str)


def extract_target_timings(log_path):
    """Extract (target_name, start_timestamp) pairs and end time from a Run Tests log."""
    targets = []
    end_time = None
    last_ts = None

    with open(log_path, 'r', errors='replace') as f:
        for line in f:
            ts_match = TIMESTAMP_RE.match(line)
            if not ts_match:
                continue
            ts = parse_timestamp(ts_match.group(1))
            last_ts = ts

            target_match = TARGET_RE.search(line)
            if target_match:
                targets.append((target_match.group(1), ts))

            if TEARDOWN_RE.search(line) or FINISHING_RE.search(line):
                end_time = ts

    if end_time is None:
        end_time = last_ts

    return targets, end_time


def compute_durations(targets, end_time):
    """
    Compute duration in seconds for each target.
    Handles retries by accumulating total time for duplicate target names.
    """
    durations = {}
    seen_indices = {}

    for i, (name, start) in enumerate(targets):
        if i + 1 < len(targets):
            next_start = targets[i + 1][1]
            duration = (next_start - start).total_seconds()
        elif end_time:
            duration = (end_time - start).total_seconds()
        else:
            duration = 0

        if name in durations:
            durations[name] += duration
        else:
            durations[name] = duration

    return durations


def find_run_tests_logs(log_dir):
    """Find all '6_Run Tests.txt' files in Server subdirectories."""
    logs = []
    for entry in os.scandir(log_dir):
        if entry.is_dir() and entry.name.startswith('Server '):
            run_tests = os.path.join(entry.path, '6_Run Tests.txt')
            if os.path.exists(run_tests):
                logs.append((entry.name, run_tests))
    return sorted(logs)


def get_action_plugin_targets(action_dir):
    """Get set of target names that have action plugins."""
    targets = set()
    if not os.path.isdir(action_dir):
        return targets
    for f in os.listdir(action_dir):
        if f.endswith('.py') and f != '__init__.py':
            targets.add(f[:-3])
    return targets


def get_all_test_targets(targets_dir):
    """Get dict of target_name -> current group number from aliases files."""
    target_groups = {}
    extra_aliases = {}
    for target in sorted(os.listdir(targets_dir)):
        aliases_path = os.path.join(targets_dir, target, 'aliases')
        if not os.path.isfile(aliases_path):
            continue
        with open(aliases_path) as f:
            lines = [l.strip() for l in f if l.strip()]
        for line in lines:
            m = re.match(r'shippable/windows/group(\d+)', line)
            if m:
                target_groups[target] = int(m.group(1))
                break
        extra_aliases[target] = [l for l in lines if not re.match(r'shippable/windows/group\d+', l)]
    return target_groups, extra_aliases


def bin_pack_groups(targets_with_durations, max_minutes, max_groups):
    """
    Distribute targets across groups evenly using longest-processing-time-first.
    Each target is placed into the least-loaded group, balancing total duration
    across all groups while respecting max_minutes as a hard ceiling.
    """
    sorted_targets = sorted(targets_with_durations, key=lambda x: x[1], reverse=True)

    groups = [[] for _ in range(max_groups)]
    group_totals = [0.0] * max_groups

    for target, duration in sorted_targets:
        min_idx = group_totals.index(min(group_totals))
        groups[min_idx].append((target, duration))
        group_totals[min_idx] += duration

    # Drop any trailing empty groups
    while groups and not groups[-1]:
        groups.pop()
        group_totals.pop()

    return groups, group_totals


def main():
    parser = argparse.ArgumentParser(description='Analyze CI logs and propose test group reorg')
    parser.add_argument('--log-dir', default='azp-logs',
                        help='Directory containing downloaded AZP logs (default: azp-logs)')
    parser.add_argument('--targets-dir', default='tests/integration/targets',
                        help='Path to integration test targets directory')
    parser.add_argument('--action-dir', default='plugins/action',
                        help='Path to action plugins directory')
    parser.add_argument('--max-minutes', type=float, default=45,
                        help='Maximum group duration in minutes (default: 45)')
    parser.add_argument('--max-groups', type=int, default=4,
                        help='Maximum number of total groups including group 1 (default: 4)')
    parser.add_argument('--apply', action='store_true',
                        help='Apply changes by updating aliases files')
    args = parser.parse_args()

    # 1. Discover action plugin targets
    action_targets = get_action_plugin_targets(args.action_dir)
    print("Action plugin targets:", sorted(action_targets))
    print()

    # 2. Get current group assignments
    target_groups, extra_aliases = get_all_test_targets(args.targets_dir)
    print(f"Total test targets with windows group assignments: {len(target_groups)}")
    print()

    # 3. Parse logs and extract per-target durations
    logs = find_run_tests_logs(args.log_dir)
    print(f"Found {len(logs)} Server Run Tests log files:")
    for dirname, _ in logs:
        print(f"  {dirname}")
    print()

    all_durations = defaultdict(list)
    for dirname, log_path in logs:
        targets, end_time = extract_target_timings(log_path)
        if not targets:
            continue
        durations = compute_durations(targets, end_time)
        for target, duration in durations.items():
            if duration > 0:
                all_durations[target].append(duration)

    # Use max duration across all server/connection combos as worst-case estimate
    target_max_durations = {}
    target_avg_durations = {}
    for target, durations in all_durations.items():
        target_max_durations[target] = max(durations)
        target_avg_durations[target] = sum(durations) / len(durations)

    DEFAULT_DURATION = 60.0
    for target in target_groups:
        if target not in target_max_durations:
            target_max_durations[target] = DEFAULT_DURATION
            target_avg_durations[target] = DEFAULT_DURATION

    # 4. Print current per-target timing
    print("=" * 85)
    print("CURRENT TIMING ANALYSIS (max duration across all server/connection combos)")
    print("=" * 85)
    print(f"{'Target':<45} {'Group':>5} {'Max':>8} {'Avg':>8} {'Action':>7}")
    print("-" * 85)

    for target in sorted(target_max_durations.keys()):
        group = target_groups.get(target, '?')
        max_dur = target_max_durations[target] / 60
        avg_dur = target_avg_durations[target] / 60
        is_action = 'YES' if target in action_targets else ''
        print(f"{target:<45} {group:>5} {max_dur:>7.1f}m {avg_dur:>7.1f}m {is_action:>7}")

    # 5. Current group totals
    print()
    print("=" * 85)
    print("CURRENT GROUP TOTALS (using max durations)")
    print("=" * 85)
    current_group_totals = defaultdict(float)
    current_group_targets = defaultdict(list)
    for target, group in target_groups.items():
        dur = target_max_durations.get(target, DEFAULT_DURATION)
        current_group_totals[group] += dur
        current_group_targets[group].append(target)

    for group in sorted(current_group_totals.keys()):
        mins = current_group_totals[group] / 60
        count = len(current_group_targets[group])
        flag = " *** OVER LIMIT ***" if mins > args.max_minutes else ""
        print(f"  Group {group}: {mins:>6.1f} min  ({count} targets){flag}")

    # 6. Build proposed groups
    print()
    print("=" * 85)
    print(f"PROPOSED REGROUPING (max {args.max_minutes} min per group, up to {args.max_groups} groups)")
    print("=" * 85)

    group1_targets = []
    remaining_targets = []

    for target in target_groups:
        dur = target_max_durations.get(target, DEFAULT_DURATION)
        if target in action_targets:
            group1_targets.append((target, dur))
        else:
            remaining_targets.append((target, dur))

    group1_total = sum(d for _, d in group1_targets)
    flag = " *** OVER LIMIT ***" if group1_total / 60 > args.max_minutes else ""
    print(f"\nGroup 1 (action plugins): {group1_total/60:.1f} min  ({len(group1_targets)} targets){flag}")
    for target, duration in sorted(group1_targets):
        old_group = target_groups.get(target, '?')
        marker = f" <- was group {old_group}" if old_group != 1 else ""
        print(f"  {target:<40} {duration/60:>7.1f}m{marker}")

    remaining_max_groups = args.max_groups - 1
    other_groups, other_totals = bin_pack_groups(remaining_targets, args.max_minutes, remaining_max_groups)

    for i, (group, total) in enumerate(zip(other_groups, other_totals)):
        group_num = i + 2
        flag = " *** OVER LIMIT ***" if total / 60 > args.max_minutes else ""
        print(f"\nGroup {group_num}: {total/60:.1f} min  ({len(group)} targets){flag}")
        for target, duration in sorted(group):
            old_group = target_groups.get(target, '?')
            marker = f" <- was group {old_group}" if old_group != group_num else ""
            print(f"  {target:<40} {duration/60:>7.1f}m{marker}")

    # 7. Summary of changes
    proposed = {}
    for target, _ in group1_targets:
        proposed[target] = 1
    for i, group in enumerate(other_groups):
        for target, _ in group:
            proposed[target] = i + 2

    changes = []
    for target in sorted(proposed.keys()):
        old = target_groups.get(target, None)
        new = proposed[target]
        if old != new:
            changes.append((target, old, new))

    print()
    print("=" * 85)
    print("CHANGES REQUIRED")
    print("=" * 85)
    if not changes:
        print("  No changes needed!")
    else:
        print(f"  {len(changes)} target(s) need to move:\n")
        print(f"  {'Target':<40} {'From':>6} {'To':>6}")
        print(f"  {'-'*40} {'-'*6} {'-'*6}")
        for target, old, new in changes:
            print(f"  {target:<40} {old:>6} {new:>6}")

    # 8. Verify proposed groups don't exceed limit
    print()
    print("=" * 85)
    print("PROPOSED GROUP SUMMARY")
    print("=" * 85)
    all_ok = True
    print(f"\n  {'Group':>7} {'Duration':>10} {'Targets':>8} {'Status':>12}")
    print(f"  {'-'*7} {'-'*10} {'-'*8} {'-'*12}")
    print(f"  {'1':>7} {group1_total/60:>9.1f}m {len(group1_targets):>8} {'OK' if group1_total/60 <= args.max_minutes else 'OVER':>12}")
    if group1_total / 60 > args.max_minutes:
        all_ok = False
    for i, (group, total) in enumerate(zip(other_groups, other_totals)):
        ok = total / 60 <= args.max_minutes
        if not ok:
            all_ok = False
        print(f"  {i+2:>7} {total/60:>9.1f}m {len(group):>8} {'OK' if ok else 'OVER':>12}")

    if not all_ok:
        print(f"\n  WARNING: Some groups exceed the {args.max_minutes} min limit.")
        print(f"  Consider increasing --max-groups (currently {args.max_groups}).")

    # 9. Apply changes if requested
    if args.apply and changes:
        print()
        print("=" * 85)
        print("APPLYING CHANGES")
        print("=" * 85)
        for target, old, new in changes:
            aliases_path = os.path.join(args.targets_dir, target, 'aliases')
            if not os.path.isfile(aliases_path):
                print(f"  SKIP {target}: aliases file not found")
                continue

            with open(aliases_path) as f:
                content = f.read()

            old_line = f'shippable/windows/group{old}'
            new_line = f'shippable/windows/group{new}'

            if old_line in content:
                content = content.replace(old_line, new_line)
                with open(aliases_path, 'w') as f:
                    f.write(content)
                print(f"  Updated {target}: group {old} -> group {new}")
            else:
                print(f"  WARN {target}: could not find '{old_line}' in aliases file")
    elif args.apply:
        print("\nNo changes to apply.")
    elif changes:
        print(f"\n  Run with --apply to update the aliases files.")


if __name__ == '__main__':
    main()
