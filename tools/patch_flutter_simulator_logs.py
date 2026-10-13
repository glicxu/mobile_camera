"""CI-only backport of Flutter PR #193142 at 249fe15ab7549656a7373f4fd1d163aea44e7a34.

One context line is adapted to the pinned 3.44.8 source; upstream code is unchanged.
The pinned 3.44.8 CLI can launch before its simulator log stream is ready,
losing the VM service URL. Wait for the log header (bounded by 30 seconds).
This changes tool startup only; test assertions and app code stay intact.
Remove after upgrading to a Flutter release that includes the upstream fix.
"""
from pathlib import Path
import shutil
import subprocess

sdk = Path(shutil.which("flutter")).resolve().parent.parent
patch = Path(__file__).with_name("flutter_simulator_log_ready.patch")
check = subprocess.run(["git", "-C", str(sdk), "apply", "--check", str(patch)], capture_output=True, text=True)
if check.returncode == 0:
    subprocess.run(["git", "-C", str(sdk), "apply", str(patch)], check=True)
else:
    # A CI SDK cache may already contain this exact backport. Reject other drift.
    reverse = subprocess.run(["git", "-C", str(sdk), "apply", "--reverse", "--check", str(patch)], capture_output=True, text=True)
    if reverse.returncode != 0:
        raise RuntimeError("Pinned Flutter source does not match the simulator patch: " + check.stderr)
    print("Exact simulator log-readiness backport already present in CI SDK cache.")
for name in ("flutter_tools.snapshot", "flutter_tools.stamp"):
    artifact = sdk / "bin" / "cache" / name
    if artifact.is_file():
        artifact.unlink()
print("Applied pinned upstream simulator log-readiness fix to CI Flutter CLI.")
