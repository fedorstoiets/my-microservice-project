"""Install checksum-verified upstream tools during the CI image build."""
import hashlib
import io
import json
import platform
from pathlib import Path
import tarfile
import urllib.request

arch = {"x86_64": "amd64", "aarch64": "arm64"}[platform.machine()]
versions = json.loads(Path("/opt/goaldevops/tool-versions.json").read_text())
for tool in ["helm", "kubectl"]:
    pin = versions[f"{tool}-{arch}"]
    version = pin["version"]
    url = (f"https://get.helm.sh/helm-{version}-linux-{arch}.tar.gz" if tool == "helm"
           else f"https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubectl")
    raw = urllib.request.urlopen(url, timeout=60).read()
    if hashlib.sha256(raw).hexdigest() != pin["sha256"]:
        raise RuntimeError(f"Checksum mismatch for {tool}")
    if tool == "helm":
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            raw = archive.extractfile(f"linux-{arch}/helm").read()
    target = Path("/usr/local/bin") / tool
    target.write_bytes(raw)
    target.chmod(0o755)
