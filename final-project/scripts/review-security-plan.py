#!/usr/bin/env python3
"""Read-only allowlist guard for the separate, in-place hardening plan."""
import argparse
import json
import re
import sys


def review(plan):
    if not isinstance(plan, dict) or str(plan.get('format_version', '')).split('.')[0] != '1' or not plan.get('terraform_version') or not isinstance(plan.get('planned_values', {}).get('root_module'), dict) or plan.get('complete') is not True or plan.get('errored') or not isinstance(plan.get('resource_changes'), list):
        return ['Unsupported, missing, incomplete or errored Terraform plan']
    problems = []
    for item in plan['resource_changes']:
        if item.get('mode', 'managed') != 'managed': continue
        change = item.get('change', {}); actions = change.get('actions'); address = item.get('address', '')
        if change.get('importing') or item.get('importing'):
            problems.append(address + ': state import is outside the hardening phase');continue
        if actions == ['no-op']: continue
        before, after = change.get('before') or {}, change.get('after') or {}
        unknown = change.get('after_unknown') or {}
        if address == 'aws_kms_key.eks_security[0]' and actions == ['create']:
            if not after.get('enable_key_rotation') or after.get('deletion_window_in_days', 0) < 30:
                problems.append('EKS key lacks required recovery/rotation policy')
            continue
        if actions != ['update']:
            problems.append(address + ': replacement/deletion/unexpected creation is prohibited');continue
        if address == 'module.eks.aws_eks_cluster.main':
            allowed = {'vpc_config', 'encryption_config'}
            config = after.get('vpc_config') or []
            if len(config) != 1 or config[0].get('endpoint_public_access') is not False or config[0].get('endpoint_private_access') is not True or config[0].get('public_access_cidrs'):
                problems.append('EKS endpoint target is not explicitly private-only')
            old_config = (before.get('vpc_config') or [{}])[0]
            if config:
                for key in ['subnet_ids', 'security_group_ids']:
                    if old_config.get(key) != config[0].get(key): problems.append('EKS network membership changed: ' + key)
        elif address == 'module.ecr.aws_ecr_repository.main':
            allowed = {'image_tag_mutability'}
            if after.get('image_tag_mutability') != 'IMMUTABLE': problems.append('ECR target is not immutable')
        elif re.fullmatch(r'module\.vpc\.aws_subnet\.public\[[0-2]\]', address):
            allowed = {'map_public_ip_on_launch'}
            if after.get('map_public_ip_on_launch') is not False: problems.append('Subnet still auto-assigns public addresses')
        else:
            problems.append(address + ': unrelated resource changed, including protected RDS/Helm');continue
        for key in set(before) | set(after):
            if before.get(key) != after.get(key) and key not in allowed and not unknown.get(key):
                problems.append(address + ': unrelated attribute changed: ' + key)
        if unknown.get('id') or before.get('id') != after.get('id'):
            problems.append(address + ': stable physical identity cannot be proven')
    if plan.get('resource_drift') or plan.get('deferred_changes'):
        problems.append('Drift/deferred changes require a new review')
    return problems


def main():
    p = argparse.ArgumentParser(description=__doc__);p.add_argument('plan', type=argparse.FileType('r'))
    args = p.parse_args();problems = review(json.load(args.plan))
    for item in problems:print(item)
    print('Security plan:', 'BLOCKED' if problems else 'within scope; independent review and explicit authorization still required')
    return bool(problems)


if __name__ == '__main__':sys.exit(main())
