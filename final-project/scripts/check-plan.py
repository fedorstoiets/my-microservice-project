#!/usr/bin/env python3
"""Fail closed on malformed/incomplete/mutating migration continuity plans."""
import argparse
import json
import sys


def managed_resources(module):
    for resource in module.get('resources', []):
        if resource.get('mode', 'managed') == 'managed':
            yield resource
    for child in module.get('child_modules', []):
        yield from managed_resources(child)


def review(plan, expected_managed_count=None):
    if not isinstance(plan, dict) or str(plan.get('format_version', '')).split('.')[0] != '1' or not plan.get('terraform_version'):
        return ['Not a supported Terraform JSON plan; never treat an empty JSON document as no-change evidence']
    if plan.get('errored') or plan.get('complete') is not True:
        return ['Plan is incomplete, errored, or lacks an explicit completeness assertion']
    values = plan.get('planned_values')
    if not isinstance(values, dict) or not isinstance(values.get('root_module'), dict) or not isinstance(plan.get('resource_changes'), list):
        return ['Plan lacks planned resource inventory or change records']
    inventory = list(managed_resources(values['root_module']))
    problems = []
    if expected_managed_count is not None and len(inventory) != expected_managed_count:
        problems.append('Planned managed inventory does not match the reviewed ownership count')
    for resource in inventory:
        if not resource.get('values', {}).get('id'):
            problems.append(resource.get('address', 'unknown') + ': physical ID missing; continuity cannot be proven')
    for resource in plan['resource_changes']:
        if resource.get('mode', 'managed') != 'managed':
            continue
        change = resource.get('change', {})
        if change.get('actions') != ['no-op'] or change.get('importing') or resource.get('importing'):
            problems.append(resource.get('address', 'unknown') + ': unapproved managed action/import')
    if plan.get('resource_drift'):
        problems.append('Refresh detected drift; investigate before proceeding')
    if plan.get('deferred_changes'):
        problems.append('Plan contains deferred changes')
    return problems


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('plan', type=argparse.FileType('r'))
    p.add_argument('--expected-managed-count', required=True, type=int, help='Reviewed target count from fresh state inventories, not a guessed number')
    args = p.parse_args()
    findings = review(json.load(args.plan), args.expected_managed_count)
    for item in findings:
        print(item)
    print('Continuity plan:', 'BLOCKED' if findings else 'no managed changes detected; physical-ID/provider/source review still required')
    return bool(findings)


if __name__ == '__main__':
    sys.exit(main())
