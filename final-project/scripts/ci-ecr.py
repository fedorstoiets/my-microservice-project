#!/usr/bin/env python3
"""ECR read-only lookup and authenticated Trivy scan; never emit registry tokens."""
import argparse
import base64
import os
import re
import subprocess


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("operation", choices=["lookup", "scan"])
    result.add_argument("reference")
    result.add_argument("--tag")
    return result


def main():
    argument_parser = parser()
    args = argument_parser.parse_args()
    if args.operation == 'lookup' and (not args.tag or not re.fullmatch(r'[a-f0-9]{40}', args.tag)):
        argument_parser.error('Lookup requires the full source SHA')
    if args.operation == 'scan' and not re.fullmatch(r'[^\s]+@sha256:[a-f0-9]{64}', args.reference):
        argument_parser.error('Scan requires an immutable image digest')
    import boto3
    client = boto3.client("ecr", region_name=os.environ["AWS_REGION"])
    registry, repository = args.reference.split("/", 1)
    if args.operation == "lookup":
        try:
            details = client.describe_images(repositoryName=repository, imageIds=[{"imageTag": args.tag}])["imageDetails"]
            print(details[0]["imageDigest"])
        except client.exceptions.ImageNotFoundException:
            print("")
        return 0
    token = client.get_authorization_token()["authorizationData"][0]["authorizationToken"]
    username, password = base64.b64decode(token).decode().split(":", 1)
    environment = dict(os.environ, TRIVY_USERNAME=username, TRIVY_PASSWORD=password)
    return subprocess.run(["trivy", "image", "--severity", "HIGH,CRITICAL", "--exit-code", "1", args.reference], env=environment).returncode


if __name__ == '__main__':
    raise SystemExit(main())
